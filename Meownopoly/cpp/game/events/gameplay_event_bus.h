/*
 *      V3 / M5 — GameplayEventBus (D1 : bus + ingestion)
 *
 * Journal d'événements métier unifié. Centralise, sous une forme typée et
 * horodatée logiquement, les signaux existants des briques V2 SANS déplacer
 * leur logique métier :
 *   - Game               (cycle de vie carte/partie ; game.h:105-121)
 *   - EditorOpBus        (mutations d'éditeur locales/distantes)
 *   - ItemSnapableEvents (vie des tuiles ; item_snapable_events.h:47-51)
 *   - PhysicsSession     (combat / runtime physique)
 *
 * Périmètre D1 : le bus et l'INGESTION seulement. Le curseur/snapshot d'audit
 * robuste (D2), les protections de cascade/cycles (D3) et le branchement au
 * canal IA `events_poll` (D4) sont des tâches distinctes — un journal borné en
 * mémoire est fourni ici comme socle minimal.
 *
 * Threads : le bus vit sur le thread GUI. L'ingestion physique passe par
 * PhysicsSession (elle-même sur le thread GUI), mais la simulation Pattounx
 * tourne dans un worker dédié — publish() est donc thread-safe (ré-ordonnancé
 * en QueuedConnection s'il est appelé hors du thread du bus) et les connexions
 * physiques sont posées en Qt::QueuedConnection par prudence.
 */
#ifndef GAMEPLAY_EVENT_BUS_H
#define GAMEPLAY_EVENT_BUS_H

#include <QHash>
#include <QObject>
#include <QQmlEngine>
#include <QQueue>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#include "event_types.h"

class GameplayEventBus : public QObject
{
    Q_OBJECT

    // Nombre total d'événements ingérés depuis le démarrage (monotone).
    Q_PROPERTY(quint64 eventCount READ eventCount NOTIFY eventCountChanged)
    // Dernière valeur d'horloge de Lamport attribuée.
    Q_PROPERTY(qint64 logicalClock READ logicalClock NOTIFY eventCountChanged)
    // --- D2 : curseur d'audit (D19) ---
    // Prochaine séquence d'audit à attribuer (= curseur de tête ; un
    // events_poll(cursor) avec cursor == cursorHead ne renvoie rien de nouveau).
    Q_PROPERTY(quint64 cursorHead READ cursorHead NOTIFY eventCountChanged)
    // Plus ancienne séquence encore consultable dans le journal borné. Si un
    // curseur consommateur est < oldestSeq, il a « décroché » → re-snapshot.
    Q_PROPERTY(quint64 oldestSeq READ oldestSeq NOTIFY eventCountChanged)
    // Taille courante du noyau d'audit (durables retenus, non désactivable).
    Q_PROPERTY(int auditCount READ auditCount NOTIFY eventCountChanged)
    // Rétention configurable du noyau d'audit (D19 : durée/verbosité/export
    // configurables ; le noyau lui-même reste non désactivable). Nombre max
    // d'événements durables conservés en mémoire.
    Q_PROPERTY(int auditRetention READ auditRetention WRITE setAuditRetention
                   NOTIFY auditRetentionChanged)
    // --- D3 : protections de cascade (D12) ---
    // Nombre d'événements REJETÉS par un garde-fou depuis le démarrage
    // (profondeur/budget/cycle dépassés). Monotone.
    Q_PROPERTY(quint64 rejectedCount READ rejectedCount NOTIFY protectionTriggered)

public:
    static void registerQml();
    static GameplayEventBus *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    quint64 eventCount() const   { return m_eventCount; }
    qint64  logicalClock() const { return m_logicalClock; }
    quint64 cursorHead() const   { return m_nextSeq - 1; }
    quint64 oldestSeq() const;
    int     auditCount() const   { return m_auditLog.size(); }
    int     auditRetention() const { return m_auditRetention; }
    void    setAuditRetention(int cap);
    quint64 rejectedCount() const { return m_rejectedCount; }

    // Publication programmatique d'un événement. Utilisée par l'ingestion des
    // sources et, à terme, par les artefacts/règles. Retourne l'id généré.
    // Thread-safe : si appelée depuis un autre thread que celui du bus,
    // l'ingestion est ré-ordonnancée en QueuedConnection. `type`/`source`
    // sont des valeurs de meow::EventType / meow::EventSource.
    Q_INVOKABLE QString publish(int type, int source, const QString &author,
                                const QVariantMap &payload = {},
                                const QString &causeId = {});

    // Connecte les sources d'ingestion. Idempotent : appelable plusieurs fois
    // (les instances de singleton manquantes sont créées à la volée). Invoqué
    // au boot par le bootstrap une fois l'event loop démarrée.
    Q_INVOKABLE void connectSources();

    // Ré-injecte le ts distant dans l'horloge locale (Lamport : le prochain
    // tick local sera > à tout ts vu). Utilisé quand un événement porteur d'un
    // ts logique arrive du réseau (consommé par D2/collab).
    Q_INVOKABLE void syncLogicalClock(qint64 remoteTs);

    // Journal courant (borné) projeté en QVariantMap, du plus ancien au plus
    // récent. Socle pour tests/debug ; le curseur robuste est eventsSince().
    Q_INVOKABLE QVariantList recentEvents(int max = 100) const;

    // --- D2 : curseur de reprise (D19 / Q-E06, socle de events_poll D4) ---
    // Renvoie les événements de séquence STRICTEMENT supérieure à `cursor`, au
    // plus `max`, du plus ancien au plus récent, sous la forme d'un snapshot :
    //   {
    //     events:     [ { …, seq }… ],   // charges projetées, ordonnées par seq
    //     count:      int,               // events.size()
    //     nextCursor: quint64,           // à repasser au prochain appel
    //     head:       quint64,           // cursorHead au moment de l'appel
    //     oldestSeq:  quint64,           // plus ancienne seq encore consultable
    //     truncated:  bool,              // true si cursor < oldestSeq (décrochage)
    //   }
    // `truncated == true` signifie que des événements postérieurs au curseur ont
    // déjà été évincés du journal borné : le consommateur doit re-synchroniser
    // par un snapshot d'état plutôt que par différentiel (Q-E06).
    Q_INVOKABLE QVariantMap eventsSince(quint64 cursor, int max = 256) const;

    // --- D2 : noyau d'audit non désactivable (D19) ---
    // Journal des seuls événements DURABLES (durabilityOf), retenu quoi qu'il
    // arrive tant qu'une action reste undoable/rejouable. Chaque entrée porte,
    // en plus de la charge, un sous-objet `audit` extrayant les champs du noyau
    // D11 présents dans le payload (proposition, verdict, raisons, amendement,
    // version appliquée) — vides tant que la couche proposition (Phase 2)
    // n'émet pas ces champs. Renvoie les entrées de seq > `sinceSeq`.
    Q_INVOKABLE QVariantList auditLog(quint64 sinceSeq = 0, int max = 256) const;

    // --- D4 : branchement du canal IA (Q-E06, manifeste eventSummary) ---
    // Portée de visibilité d'un rôle du canal sur le journal (D20/Q-E06) :
    //   0 = proposer → événements PUBLICS de la partie ;
    //   1 = arbiter  → en plus, propositions en file + amendements.
    // (Aligné sur AiGatewayServer::Role, sans coupler les deux enums.)
    enum CanalAudience { AudienceProposer = 0, AudienceArbiter = 1 };

    // events_poll(cursor) : réponse au format Q-E06 `eventSummary.pollResponse`.
    // Reprend le différentiel du journal métier depuis `cursor` (seq strictement
    // supérieure), projeté dans le SCHÉMA CANAL (curé, distinct de la projection
    // brute toVariantMap) : chaque entrée = { seq, ts (ISO-8601), type (nom canal
    // ex. "tile.placed"), actor, summary (phrase courte), refs ([uuid]) }.
    //   {
    //     entries:    [ { seq, ts, type, actor, summary, refs } ],
    //     nextCursor: integer,   // à repasser au prochain events_poll
    //     truncated:  bool,      // cursor décroché (< oldestSeq) → resync state_query
    //     oldestSeq:  integer,   // plus ancienne seq encore consultable
    //     count:      integer,
    //   }
    // `audience` filtre les événements réservés à l'arbitre (D20).
    Q_INVOKABLE QVariantMap canalPoll(quint64 cursor,
                                      int audience = AudienceProposer,
                                      int max = 256) const;

    // Résumé injecté par invocation (Q-E06 `eventSummary.injectedBlock`). Bloc
    // compact prêt à préfixer le prompt d'un tour d'IA (une invocation = un tour,
    // D25). Ne retient que les types PERTINENTS (tile.placed, proposal.verdict,
    // memory.changed, rules.changed) ; compte par catégorie et énumère au plus
    // `maxLines` lignes (défaut 250, D44) avec marqueur de dépassement renvoyant
    // vers events_poll. Retourne :
    //   {
    //     text:       string,    // bloc humain compact à injecter
    //     fromSeq:    integer,   // cursor + 1
    //     toSeq:      integer,   // cursorHead au moment de l'appel
    //     matched:    integer,   // événements pertinents dans la fenêtre
    //     listed:     integer,   // lignes réellement énumérées (≤ maxLines)
    //     omitted:    integer,   // matched - listed
    //     nextCursor: integer,
    //     truncated:  bool,
    //     oldestSeq:  integer,
    //   }
    Q_INVOKABLE QVariantMap canalSummary(quint64 cursor,
                                         int audience = AudienceProposer,
                                         int maxLines = 250) const;

    // Nom canal stable d'un type d'événement ("tile.placed", "memory.changed"…).
    // Public : c'est la taxonomie des `trigger` de règles (T4-4, doc v3/06 §5.2)
    // en plus de la projection canal D4.
    static QString canalTypeName(meow::EventType type);

signals:
    // Émis pour chaque événement ingéré (durable ou éphémère). Les abonnés
    // filtrent par `source`/`type`/`durability` dans la charge projetée.
    void eventPublished(const QVariantMap &event);
    void eventCountChanged();
    void auditRetentionChanged();
    // Émis quand un garde-fou D12 rejette un événement (non ingéré). `reason`
    // ∈ {"depth", "budget", "cycle", "queue"} ; `event` est la charge rejetée.
    void protectionTriggered(const QString &reason, const QVariantMap &event);

private:
    explicit GameplayEventBus(QObject *parent = nullptr);
    static GameplayEventBus *m_instance;

    // Horloge de Lamport locale — même principe que game_lamport.cpp : un
    // compteur logique monotone. On garde une horloge DÉDIÉE aux événements
    // plutôt que de réutiliser Game::tickLamport() (qui pilote le zOrder des
    // tuiles et serait pollué par la cadence des événements — cf. note de
    // conception dans le .cpp).
    qint64 tickLamport();

    // Marshalling thread-safe puis archivage + diffusion.
    void dispatchIngest(const meow::GameplayEvent &ev);
    // Point d'entrée d'ingestion : met en file et draine (D3 : file
    // transactionnelle — une émission en cours ne ré-entre pas, elle empile).
    void ingest(meow::GameplayEvent ev);
    // Draine la file `m_pending` en série. Chaque événement passe par admit()
    // (garde-fous D12) puis, s'il est admis, par commit().
    void drainQueue();
    // Renseigne rootId/depth et applique les protections D12 (profondeur, budget
    // de cascade, cycle/write-set). Retourne false si l'événement est rejeté
    // (protectionTriggered émis, non ingéré).
    bool admit(meow::GameplayEvent &ev);
    // Archivage effectif : seq, Lamport, journaux, signaux.
    void commit(meow::GameplayEvent ev);
    // Cible d'écriture d'un événement pour la détection de cycle (tileId, sinon
    // "target"/"key" du payload). Vide si aucune cible identifiable.
    static QString writeTargetOf(const meow::GameplayEvent &ev);

    // Câblage par source (chacune tolère l'absence de son singleton).
    void connectGame();
    void connectEditorOps();
    void connectTiles();
    void connectPhysics();

    // Extraction du sous-objet d'audit (noyau D11) depuis le payload d'un
    // événement durable — proposition/verdict/raisons/amendement/version.
    static QVariantMap extractAuditCore(const meow::GameplayEvent &ev);

    // --- D4 : projection au schéma canal (Q-E06) ---
    // (canalTypeName est déclarée publique ci-dessus — taxonomie partagée avec
    // les triggers de règles T4-4.)
    // Vrai si un événement de ce type canal est visible pour l'audience donnée.
    // Les propositions/amendements (arbitre-only) ne sont pas encore émis
    // (Phase 2) → tout est public au MVP, mais le point de filtrage existe.
    static bool       canalVisibleTo(const QString &canalType, int audience);
    // Vrai si le type canal fait partie des types PERTINENTS du résumé injecté.
    static bool       canalRelevant(const QString &canalType);
    // Entrée canal curée d'un événement (schéma Q-E06 entry).
    static QVariantMap canalEntryOf(const meow::GameplayEvent &ev);
    // Phrase courte lisible décrivant un événement (champ `summary`).
    static QString    canalPhraseOf(const meow::GameplayEvent &ev);
    // uuids touchés par l'événement (champ `refs`).
    static QStringList canalRefsOf(const meow::GameplayEvent &ev);

    bool    m_sourcesConnected = false;
    qint64  m_logicalClock     = 0;
    quint64 m_eventCount       = 0;

    // --- D2 : curseur d'audit ---
    // Séquence d'audit strictement monotone attribuée à l'ingestion. `m_nextSeq`
    // est la prochaine valeur libre (curseur de tête = m_nextSeq - 1).
    quint64 m_nextSeq = 1;

    // Journal général en mémoire, borné (ring souple). Alimente recentEvents()
    // et eventsSince() (events_poll). Chaque entrée porte sa `seq`.
    QVector<meow::GameplayEvent> m_journal;
    static constexpr int k_journalCap = 4096;

    // Noyau d'audit non désactivable (D19) : seuls les événements DURABLES,
    // retenus au-delà du journal général (rétention configurable). Ordonné par
    // seq croissante comme m_journal.
    QVector<meow::GameplayEvent> m_auditLog;
    int m_auditRetention = 16384;

    // --- D3 : file transactionnelle + garde-fous de cascade (D12) ---
    // File sérialisant l'ingestion : si un abonné de eventPublished publie à son
    // tour (cascade de règle), l'événement est empilé et traité après l'événement
    // courant, jamais en ré-entrance. Bornée pour éviter l'emballement mémoire.
    QQueue<meow::GameplayEvent> m_pending;
    bool m_draining = false;

    // État causal, vivant le temps d'une cascade (vidé quand la file se tarit) :
    //   depthOf / rootOf : profondeur et racine par id d'événement admis ;
    //   cascadeCount     : nb de descendants admis par racine (budget) ;
    //   writeHits        : nb d'écritures par (racine → cible) (détection cycle).
    QHash<QString, quint32> m_depthOf;
    QHash<QString, QString> m_rootOf;
    QHash<QString, int>     m_cascadeCount;
    QHash<QString, QHash<QString, int>> m_writeHits;

    quint64 m_rejectedCount = 0;

    // Plafonds (D12). Un événement racine (sans causeId) n'est jamais rejeté par
    // profondeur/budget/cycle : seule la borne de file le protège.
    static constexpr quint32 k_maxDepth     = 32;    // profondeur causale max
    static constexpr int     k_maxCascade   = 512;   // descendants max par racine
    static constexpr int     k_maxWriteHits = 64;    // écritures max sur 1 cible / racine
    static constexpr int     k_maxQueue     = 16384; // taille max de la file
};

#endif // GAMEPLAY_EVENT_BUS_H
