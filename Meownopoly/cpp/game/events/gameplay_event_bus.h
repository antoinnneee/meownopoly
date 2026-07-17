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

#include <QObject>
#include <QQmlEngine>
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

signals:
    // Émis pour chaque événement ingéré (durable ou éphémère). Les abonnés
    // filtrent par `source`/`type`/`durability` dans la charge projetée.
    void eventPublished(const QVariantMap &event);
    void eventCountChanged();
    void auditRetentionChanged();

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
    void ingest(meow::GameplayEvent ev);

    // Câblage par source (chacune tolère l'absence de son singleton).
    void connectGame();
    void connectEditorOps();
    void connectTiles();
    void connectPhysics();

    // Extraction du sous-objet d'audit (noyau D11) depuis le payload d'un
    // événement durable — proposition/verdict/raisons/amendement/version.
    static QVariantMap extractAuditCore(const meow::GameplayEvent &ev);

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
};

#endif // GAMEPLAY_EVENT_BUS_H
