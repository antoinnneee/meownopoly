/*
 *      V3 / T3-3 (M6-B) — Bus d'état runtime host-authoritative (D35/D39)
 *
 * Transport générique de l'état runtime partagé (namespace `state` de la
 * mémoire, doc v3/05 Étape B) au-dessus de la pile V3 (enveloppe B1,
 * supersedable B3, ACK applicatif B2 côté Catway). Patron inspiré de
 * PhysicsSession (state-sync host-authoritative, `physics_session.cpp:332+`)
 * mais RÉ-IMPLÉMENTÉ générique — pas de fusion avec la session physique
 * (audit F04) : le bus ne connaît ni tuiles ni joueurs, seulement des
 * couples (namespace, clé) opaques.
 *
 * Modèle (D35, ferme Q-F05/Q-F06/Q-F07) :
 *  - L'HÔTE est autoritatif sur toutes les valeurs. Un client qui écrit
 *    route une INTENTION vers l'hôte (`state.intent`, classe commit : ACK
 *    applicatif B2 + dédup, jamais appliquée localement en optimiste).
 *  - L'hôte applique en LWW SÉQUENCÉ : ordre d'arrivée autoritatif, chaque
 *    écriture acceptée reçoit une séquence monotone par clé
 *    (V3SupersedableState::nextSeq).
 *  - Diffusion par DELTAS COALESCÉS par (namespace, clé) à 30 Hz max
 *    (`state.delta`, classe supersedable : séquence + snapshot de
 *    réparation, pas d'ACK applicatif — un delta perdu attend le prochain
 *    snapshot, jamais de retransmission).
 *  - SNAPSHOT DE RÉPARATION périodique (~5 s ou 128 deltas) : état complet
 *    + socle de séquences + HASH DE DIVERGENCE (D39). Un pair dont le hash
 *    local diverge après application demande un resync
 *    (`state.request_snapshot` → snapshot ciblé).
 *  - SNAPSHOT STRUCTUREL : à signaler via notifyStructuralChange() à chaque
 *    ajout/suppression d'item, et envoyé à l'entrée d'un pair
 *    (`state.hello` du client → snapshot ciblé).
 *
 * Plafonds D35 (rejet à la source `{code: "quota_exceeded",
 * retryable: false}`, jamais de troncature silencieuse) :
 *  - 1 KB / valeur ; 8 KB / namespace (tuile) ; 256 KB / session ;
 *  - ~64 KB/s / pair (fenêtre glissante 1 s, intentions côté hôte et
 *    émission côté client) ; 30 Hz max par (namespace, clé) via coalescence.
 *
 * Généricité / branchement : le bus est un pur transport + miroir de
 * valeurs. Les consommateurs (bridge ItemSnapable.userMemory["state"],
 * MemoryStore, règles) : 1) poussent leurs écritures via submitWrite() /
 * submitRemove() ; 2) appliquent UNIQUEMENT sur les signaux valueApplied /
 * valueRemoved / namespaceDropped (point d'application unique, y compris
 * pour les écritures locales de l'hôte — pas d'application directe au
 * submit, donc pas de boucle réactive). Ce câblage appartient à
 * l'intégration (T3-5), pas à cette brique.
 *
 * Hors session (active == false), le bus se comporte en autorité locale
 * (mode solo) : submitWrite applique immédiatement, aucun trafic réseau.
 *
 * Threading : GUI thread uniquement (comme PhysicsSession/EditorSession —
 * les signaux Catway arrivent sur le GUI thread).
 */
#ifndef STATE_BUS_H
#define STATE_BUS_H

#include "net/v3/v3_supersedable_state.h"

#include <QHash>
#include <QJsonObject>
#include <QObject>
#include <QPair>
#include <QQmlEngine>
#include <QSet>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QVariant>
#include <QVariantMap>

// ── Plafonds D35 (surchargeables au build, jamais de troncature) ────────────
#ifndef MEOW_STATEBUS_MAX_VALUE_BYTES
#define MEOW_STATEBUS_MAX_VALUE_BYTES (1 * 1024)       // 1 KB / valeur
#endif
#ifndef MEOW_STATEBUS_MAX_NS_BYTES
#define MEOW_STATEBUS_MAX_NS_BYTES (8 * 1024)          // 8 KB / namespace (tuile)
#endif
#ifndef MEOW_STATEBUS_MAX_SESSION_BYTES
#define MEOW_STATEBUS_MAX_SESSION_BYTES (256 * 1024)   // 256 KB / session
#endif
#ifndef MEOW_STATEBUS_MAX_PEER_BYTES_PER_SEC
#define MEOW_STATEBUS_MAX_PEER_BYTES_PER_SEC (64 * 1024) // ~64 KB/s / pair
#endif
#ifndef MEOW_STATEBUS_DELTA_HZ
#define MEOW_STATEBUS_DELTA_HZ 30                      // coalescence 30 Hz max
#endif
#ifndef MEOW_STATEBUS_REPAIR_INTERVAL_MS
#define MEOW_STATEBUS_REPAIR_INTERVAL_MS 5000          // snapshot réparation ~5 s
#endif
#ifndef MEOW_STATEBUS_REPAIR_DELTA_COUNT
#define MEOW_STATEBUS_REPAIR_DELTA_COUNT 128           // …ou 128 deltas
#endif

class StateBus : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool isHost READ isHost NOTIFY isHostChanged)
    Q_PROPERTY(QString sessionId READ sessionId NOTIFY sessionIdChanged)
    Q_PROPERTY(QString localPlayerId READ localPlayerId NOTIFY localPlayerIdChanged)
    Q_PROPERTY(QString hostPlayerId READ hostPlayerId NOTIFY hostPlayerIdChanged)
    // Compteurs d'introspection (panel de test réseau).
    Q_PROPERTY(quint64 deltasSent READ deltasSent NOTIFY countersChanged)
    Q_PROPERTY(quint64 deltasReceived READ deltasReceived NOTIFY countersChanged)
    Q_PROPERTY(quint64 snapshotsSent READ snapshotsSent NOTIFY countersChanged)
    Q_PROPERTY(quint64 snapshotsReceived READ snapshotsReceived NOTIFY countersChanged)
    Q_PROPERTY(quint64 intentsSent READ intentsSent NOTIFY countersChanged)
    Q_PROPERTY(quint64 intentsReceived READ intentsReceived NOTIFY countersChanged)
    Q_PROPERTY(quint64 rejectsEmitted READ rejectsEmitted NOTIFY countersChanged)

public:
    static void registerQml();
    static StateBus *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    bool active() const            { return m_active; }
    bool isHost() const            { return m_isHost; }
    QString sessionId() const      { return m_sessionId; }
    QString localPlayerId() const  { return m_localPlayerId; }
    QString hostPlayerId() const   { return m_hostPlayerId; }
    quint64 deltasSent() const     { return m_deltasSent; }
    quint64 deltasReceived() const { return m_deltasReceived; }
    quint64 snapshotsSent() const  { return m_snapshotsSent; }
    quint64 snapshotsReceived() const { return m_snapshotsReceived; }
    quint64 intentsSent() const    { return m_intentsSent; }
    quint64 intentsReceived() const { return m_intentsReceived; }
    quint64 rejectsEmitted() const { return m_rejectsEmitted; }

    // ── Cycle de vie ─────────────────────────────────────────────────────────
    /// Démarre comme hôte autoritatif. L'état local courant devient la vérité
    /// de session ; un snapshot structurel part vers les pairs déjà connectés.
    Q_INVOKABLE bool startAsHost(const QString &sessionId,
                                 const QString &localPlayerId);

    /// Démarre comme client : purge le miroir local (l'état de l'hôte fait
    /// foi) puis envoie `state.hello` (retry 500 ms tant que l'hôte n'est pas
    /// joignable dans Catway — hole punch en cours).
    Q_INVOKABLE bool startAsClient(const QString &sessionId,
                                   const QString &localPlayerId,
                                   const QString &hostPlayerId);

    /// Arrête la session. Le miroir de valeurs est CONSERVÉ (reprise locale /
    /// migration d'hôte : l'élu repart de son dernier état répliqué) ; les
    /// files réseau et fenêtres de débit sont purgées. clearAll() pour un
    /// vrai wipe.
    Q_INVOKABLE void stop();

    /// Vide totalement le bus (valeurs + séquences + files). Nouvelle partie.
    Q_INVOKABLE void clearAll();

    // ── Écritures (point d'entrée unique producteurs) ────────────────────────
    /// Écrit une valeur d'état. Hôte/solo : application autoritaire immédiate
    /// (signal valueApplied) + delta coalescé. Client : intention routée vers
    /// l'hôte (B2), application différée au retour du delta. Retourne false si
    /// rejet immédiat (plafond D35, type non sérialisable, débit) — le rejet
    /// asynchrone de l'hôte arrive par writeRejected.
    Q_INVOKABLE bool submitWrite(const QString &ns, const QString &key,
                                 const QVariant &value);

    /// Supprime une clé d'état (mêmes régimes que submitWrite).
    Q_INVOKABLE bool submitRemove(const QString &ns, const QString &key);

    /// Hôte/solo uniquement : oublie tout un namespace (tuile supprimée) puis
    /// diffuse un snapshot structurel. Les clients reçoivent la disparition
    /// via le snapshot (clés absentes → drop) + signal namespaceDropped.
    Q_INVOKABLE bool dropNamespace(const QString &ns);

    /// À appeler par l'intégration à chaque changement structurel (ajout /
    /// suppression d'item porteur d'état) : l'hôte diffuse immédiatement un
    /// snapshot structurel. No-op côté client / hors session.
    Q_INVOKABLE void notifyStructuralChange();

    /// Client : demande explicite de resync (`state.request_snapshot`).
    /// Utilisée aussi en interne sur divergence de hash (D39).
    Q_INVOKABLE void requestStateSnapshot();

    // ── Lecture du miroir local ──────────────────────────────────────────────
    Q_INVOKABLE QVariant value(const QString &ns, const QString &key) const;
    Q_INVOKABLE bool contains(const QString &ns, const QString &key) const;
    Q_INVOKABLE QVariantMap namespaceValues(const QString &ns) const;
    Q_INVOKABLE QStringList namespaces() const;
    /// Hash de divergence D39 de l'état local complet ("sha256:<hex>").
    Q_INVOKABLE QString localStateHash() const;

signals:
    void activeChanged();
    void isHostChanged();
    void sessionIdChanged();
    void localPlayerIdChanged();
    void hostPlayerIdChanged();
    void countersChanged();

    /// POINT D'APPLICATION UNIQUE : une valeur d'état a été (autoritairement)
    /// écrite — chez l'hôte à l'acceptation, chez les clients à la réception
    /// du delta/snapshot. Les consommateurs appliquent ici, jamais au submit.
    void valueApplied(const QString &ns, const QString &key,
                      const QVariant &value, quint64 seq);
    /// Une clé d'état a été supprimée (même contrat que valueApplied).
    void valueRemoved(const QString &ns, const QString &key, quint64 seq);
    /// Un namespace entier a disparu (structurel).
    void namespaceDropped(const QString &ns);

    /// Écriture refusée. `code` ∈ {"quota_exceeded", "rate_limited",
    /// "not_serializable", "invalid_arguments"} ; `retryable` false pour les
    /// quotas D35 (remonté tel quel à l'IA, D35). Émis localement (rejet à la
    /// source) ou à réception d'un `state.reject` de l'hôte.
    void writeRejected(const QString &ns, const QString &key,
                       const QString &code, bool retryable);

    /// Un snapshot a été appliqué (`reason` ∈ {"repair", "structural",
    /// "hello", "request"}). Après application, tout l'état local reflète
    /// l'hôte — utile aux consommateurs qui préfèrent re-scanner.
    void snapshotApplied(const QString &reason);

    /// D39 : hash local ≠ hash hôte après application d'un snapshot →
    /// un resync (`requestStateSnapshot`) est déclenché automatiquement.
    void divergenceDetected(const QString &hostHash, const QString &localHash);

private slots:
    void onReliableReceived(const QString &senderId, const QByteArray &data);
    void onPlayerTimedOut(const QString &playerId);
    void onV3MessageFailed(const QString &playerId, const QString &messageId,
                           const QString &reason);
    void onFlushTimerFired();
    void onRepairTimerFired();

private:
    explicit StateBus(QObject *parent = nullptr);
    static StateBus *m_pThis;

    // ── Câblage Catway ───────────────────────────────────────────────────────
    void connectToCatway();
    void disconnectFromCatway();
    bool sendHelloToHost();

    // ── Cœur autoritatif (hôte / solo) ──────────────────────────────────────
    /// Applique une écriture en autorité (quotas D35 inclus). `senderId` vide
    /// = écriture locale. Retourne le code de rejet ("" si acceptée).
    QString applyAuthoritative(const QString &ns, const QString &key,
                               const QVariant &value, bool isRemove);
    void queueDelta(const QString &ns, const QString &key,
                    const QVariant &value, bool isRemove, quint64 seq);
    void broadcastSnapshot(const QString &reason, const QString &targetPeerId);
    QJsonObject buildSnapshotPayload(const QString &reason) const;
    void sendReject(const QString &peerId, const QString &ns,
                    const QString &key, const QString &code,
                    const QString &correlationId);

    // ── Réception ────────────────────────────────────────────────────────────
    void handleIntent(const QString &senderId, const QJsonObject &payload,
                      const QString &messageId, int packetBytes);
    void handleDelta(const QJsonObject &payload);
    void handleSnapshot(const QJsonObject &payload);
    void handleReject(const QJsonObject &payload);

    // ── Quotas D35 ───────────────────────────────────────────────────────────
    /// Taille sérialisée (JSON compact) d'une valeur ; -1 si non sérialisable.
    static int valueSizeBytes(const QVariant &value);
    static int entrySizeBytes(const QString &key, int valueBytes);
    /// Vérifie les plafonds taille pour une écriture sur le miroir courant.
    /// Retourne "" si OK, sinon le code de rejet.
    QString checkSizeQuotas(const QString &ns, const QString &key,
                            int valueBytes) const;
    /// Fenêtre glissante 1 s par pair. Retourne false si le budget est épuisé.
    bool consumePeerBudget(const QString &peerId, int bytes);

    // ── Miroir local ─────────────────────────────────────────────────────────
    void storeValue(const QString &ns, const QString &key, const QVariant &value);
    void eraseValue(const QString &ns, const QString &key);
    static QString compositeKey(const QString &ns, const QString &key)
    { return ns + QLatin1Char('/') + key; }

    // ── Envoi enveloppé ─────────────────────────────────────────────────────
    /// Fabrique l'enveloppe B1 (seq de transport monotone locale) et le paquet
    /// fil. `messageIdOut` reçoit l'id (suivi B2) si non nul.
    QByteArray packEnvelope(const QString &kind, const QJsonObject &payload,
                            const QString &correlationId = QString(),
                            QString *messageIdOut = nullptr);

    bool    m_active = false;
    bool    m_isHost = false;
    QString m_sessionId;
    QString m_localPlayerId;
    QString m_hostPlayerId;

    /// Miroir de valeurs : ns → (clé → valeur). Autoritatif chez l'hôte,
    /// répliqué chez les clients.
    QHash<QString, QVariantMap> m_values;
    /// Comptabilité de taille pour les plafonds (octets sérialisés par entrée).
    QHash<QString, int> m_nsBytes;       ///< ns → octets du namespace.
    QHash<QString, int> m_entryBytes;    ///< clé composite → octets de l'entrée.
    int m_totalBytes = 0;

    /// Séquences supersedables par clé composite (B3). Hôte : producteur
    /// (nextSeq) ; client : filtre drop-de-l'ancien (offer/applySnapshot).
    V3SupersedableState m_seqState;

    /// Hôte : deltas en attente, coalescés par clé composite (LWW dans le
    /// batch). value invalide + isRemove → suppression.
    struct PendingDelta {
        QString  ns;
        QString  key;
        QVariant value;
        bool     isRemove = false;
        quint64  seq = 0;
    };
    QHash<QString, PendingDelta> m_pendingDeltas;
    QTimer m_flushTimer;    ///< 30 Hz, actif seulement si m_pendingDeltas non vide.
    QTimer m_repairTimer;   ///< ~5 s, hôte actif seulement.
    QTimer m_helloRetryTimer; ///< client : retry Hello tant que l'hôte est injoignable.
    int m_deltasSinceRepair = 0;
    quint64 m_snapshotSeqOut = 0;  ///< numéro de snapshot hôte (monotone).
    quint64 m_envelopeSeqOut = 0;  ///< seq de transport B1 (par émetteur).

    /// Fenêtres de débit par pair {pairId → (débutFenêtreMs, octets)}.
    /// Côté hôte : intentions entrantes ; côté client : émissions sortantes
    /// (clé = id local).
    QHash<QString, QPair<qint64, int>> m_peerBudgets;

    /// messageIds B2 émis par ce bus encore en vol → kind (retry ciblé sur
    /// v3MessageFailed pour hello / request_snapshot).
    QHash<QString, QString> m_outgoingTracked;

    /// D39 : une demande de resync est déjà en vol (anti-tempête).
    bool m_snapshotRequestPending = false;

    quint64 m_deltasSent = 0, m_deltasReceived = 0;
    quint64 m_snapshotsSent = 0, m_snapshotsReceived = 0;
    quint64 m_intentsSent = 0, m_intentsReceived = 0;
    quint64 m_rejectsEmitted = 0;

    QMetaObject::Connection m_reliableConn;
    QMetaObject::Connection m_timeoutConn;
    QMetaObject::Connection m_failedConn;
};

#endif // STATE_BUS_H
