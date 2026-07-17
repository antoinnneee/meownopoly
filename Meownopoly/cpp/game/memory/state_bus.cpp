/*
 *      V3 / T3-3 (M6-B) — Bus d'état runtime host-authoritative (D35/D39)
 *
 * Implémentation. Voir state_bus.h pour le modèle complet. Points clés :
 *  - LWW séquencé hôte : applyAuthoritative() est l'UNIQUE chemin de mutation
 *    (écritures locales hôte, intentions distantes, mode solo) ;
 *  - deltas coalescés par (ns, clé) à 30 Hz via m_pendingDeltas + m_flushTimer ;
 *  - snapshot de réparation ~5 s / 128 deltas, portant le hash D39 ;
 *  - snapshot structurel (notifyStructuralChange / hello d'un pair) ;
 *  - plafonds D35, rejet `quota_exceeded` non-retryable à la source.
 *
 * Patron réseau inspiré de PhysicsSession (state-sync host-authoritative)
 * ré-implémenté générique — aucune fusion avec la session physique (F04).
 */
#include "state_bus.h"

#include "communication/catway.h"
#include "communication/player_network.h"
#include "net/v3/v3_envelope.h"
#include "net/v3/v3_protocol.h"

#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonValue>
#include <QtQml>

namespace {
// Kinds applicatifs du bus (discriminant `kind` de l'enveloppe B1).
const QString kKindIntent          = QStringLiteral("state.intent");
const QString kKindDelta           = QStringLiteral("state.delta");
const QString kKindSnapshot        = QStringLiteral("state.snapshot");
const QString kKindRequestSnapshot = QStringLiteral("state.request_snapshot");
const QString kKindHello           = QStringLiteral("state.hello");
const QString kKindReject          = QStringLiteral("state.reject");

// Codes de rejet (contrat D35 : remontés tels quels, jamais de troncature).
const QString kCodeQuota           = QStringLiteral("quota_exceeded");
const QString kCodeNotSerializable = QStringLiteral("not_serializable");
const QString kCodeInvalidArgs     = QStringLiteral("invalid_arguments");
} // namespace

StateBus *StateBus::m_pThis = nullptr;

// ── Singleton ────────────────────────────────────────────────────────────────

StateBus::StateBus(QObject *parent) : QObject(parent)
{
    // Coalescence 30 Hz : le timer ne tourne que si des deltas sont en attente.
    m_flushTimer.setTimerType(Qt::PreciseTimer);
    m_flushTimer.setInterval(qRound(1000.0 / MEOW_STATEBUS_DELTA_HZ));
    connect(&m_flushTimer, &QTimer::timeout, this, &StateBus::onFlushTimerFired);

    // Snapshot de réparation périodique (hôte actif uniquement).
    m_repairTimer.setInterval(MEOW_STATEBUS_REPAIR_INTERVAL_MS);
    connect(&m_repairTimer, &QTimer::timeout, this, &StateBus::onRepairTimerFired);

    // Client : retry du Hello tant que l'hôte n'est pas joignable dans Catway
    // (hole punch en cours) — même patron que PhysicsSession.
    m_helloRetryTimer.setInterval(500);
    connect(&m_helloRetryTimer, &QTimer::timeout, this, [this]() {
        if (!m_active || m_isHost) { m_helloRetryTimer.stop(); return; }
        if (sendHelloToHost()) m_helloRetryTimer.stop();
    });
}

StateBus *StateBus::instance()
{
    if (!m_pThis) m_pThis = new StateBus();
    return m_pThis;
}

QObject *StateBus::qmlInstance(QQmlEngine *, QJSEngine *) { return instance(); }

void StateBus::registerQml()
{
    qmlRegisterSingletonType<StateBus>("MeowMemory", 1, 0, "StateBus",
                                       &StateBus::qmlInstance);
}

// ── Cycle de vie ────────────────────────────────────────────────────────────

bool StateBus::startAsHost(const QString &sessionId, const QString &localPlayerId)
{
    if (sessionId.isEmpty() || localPlayerId.isEmpty()) {
        qWarning() << "[StateBus] startAsHost: arguments vides";
        return false;
    }
    if (m_active) stop();

    m_sessionId     = sessionId;
    m_localPlayerId = localPlayerId;
    m_hostPlayerId  = localPlayerId;
    m_isHost = true;
    m_active = true;

    connectToCatway();
    m_repairTimer.start();

    // Snapshot structurel initial : les pairs déjà connectés (Catway persiste
    // les PlayerNetwork à travers les sessions) reçoivent l'état de départ.
    broadcastSnapshot(QStringLiteral("structural"), QString());

    emit sessionIdChanged();
    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit isHostChanged();
    emit activeChanged();
    qDebug() << "[StateBus] HOST start, session =" << sessionId
             << "playerId =" << localPlayerId;
    return true;
}

bool StateBus::startAsClient(const QString &sessionId,
                             const QString &localPlayerId,
                             const QString &hostPlayerId)
{
    if (sessionId.isEmpty() || localPlayerId.isEmpty() || hostPlayerId.isEmpty()) {
        qWarning() << "[StateBus] startAsClient: arguments vides";
        return false;
    }
    if (m_active) stop();

    // L'état de l'hôte fait foi : wipe silencieux du miroir local (les
    // consommateurs se resynchronisent sur snapshotApplied, envoyé par l'hôte
    // en réponse au Hello).
    m_values.clear();
    m_nsBytes.clear();
    m_entryBytes.clear();
    m_totalBytes = 0;
    m_seqState.clear();

    m_sessionId     = sessionId;
    m_localPlayerId = localPlayerId;
    m_hostPlayerId  = hostPlayerId;
    m_isHost = false;
    m_active = true;

    connectToCatway();

    if (!sendHelloToHost()) {
        qWarning() << "[StateBus] CLIENT start : hôte introuvable dans Catway"
                   << hostPlayerId << "— Hello non envoyé, retry armé (500 ms)";
        m_helloRetryTimer.start();
    }

    emit sessionIdChanged();
    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit isHostChanged();
    emit activeChanged();
    qDebug() << "[StateBus] CLIENT start, session =" << sessionId
             << "playerId =" << localPlayerId << "host =" << hostPlayerId;
    return true;
}

void StateBus::stop()
{
    if (!m_active && m_sessionId.isEmpty()) return;

    disconnectFromCatway();
    m_flushTimer.stop();
    m_repairTimer.stop();
    m_helloRetryTimer.stop();

    // Le miroir de valeurs et les séquences sont CONSERVÉS (reprise locale /
    // migration d'hôte : l'élu repart de son dernier état répliqué). Seul le
    // transitoire réseau est purgé.
    m_pendingDeltas.clear();
    m_peerBudgets.clear();
    m_outgoingTracked.clear();
    m_snapshotRequestPending = false;
    m_deltasSinceRepair = 0;

    m_active = false;
    m_isHost = false;
    m_sessionId.clear();
    m_hostPlayerId.clear();

    m_deltasSent = m_deltasReceived = 0;
    m_snapshotsSent = m_snapshotsReceived = 0;
    m_intentsSent = m_intentsReceived = 0;
    m_rejectsEmitted = 0;

    emit activeChanged();
    emit isHostChanged();
    emit sessionIdChanged();
    emit hostPlayerIdChanged();
    emit countersChanged();
    qDebug() << "[StateBus] stopped";
}

void StateBus::clearAll()
{
    const QStringList droppedNs = m_values.keys();
    m_values.clear();
    m_nsBytes.clear();
    m_entryBytes.clear();
    m_totalBytes = 0;
    m_seqState.clear();
    m_pendingDeltas.clear();
    m_deltasSinceRepair = 0;
    for (const QString &ns : droppedNs)
        emit namespaceDropped(ns);
    // Hôte actif : les pairs doivent refléter le wipe.
    if (m_active && m_isHost)
        broadcastSnapshot(QStringLiteral("structural"), QString());
}

// ── Câblage Catway ──────────────────────────────────────────────────────────

void StateBus::connectToCatway()
{
    Catway *catway = Catway::instance();
    m_reliableConn = connect(catway, &Catway::reliableMessageReceived,
                             this,   &StateBus::onReliableReceived);
    m_timeoutConn  = connect(catway, &Catway::playerTimedOut,
                             this,   &StateBus::onPlayerTimedOut);
    m_failedConn   = connect(catway, &Catway::v3MessageFailed,
                             this,   &StateBus::onV3MessageFailed);
    // Ménage : un message confirmé n'a plus besoin de suivi local.
    connect(catway, &Catway::v3MessageAcked, this,
            [this](const QString &, const QString &messageId) {
                m_outgoingTracked.remove(messageId);
            });
}

void StateBus::disconnectFromCatway()
{
    disconnect(m_reliableConn);
    disconnect(m_timeoutConn);
    disconnect(m_failedConn);
    disconnect(Catway::instance(), &Catway::v3MessageAcked, this, nullptr);
}

bool StateBus::sendHelloToHost()
{
    if (m_hostPlayerId.isEmpty()) return false;
    if (!Catway::instance()->playerById(m_hostPlayerId)) return false;

    QString messageId;
    const QByteArray pkt = packEnvelope(kKindHello, QJsonObject(), QString(),
                                        &messageId);
    Catway::instance()->sendV3Reliable(m_hostPlayerId, pkt, messageId);
    m_outgoingTracked.insert(messageId, kKindHello);
    qDebug() << "[StateBus] CLIENT → Hello envoyé à" << m_hostPlayerId;
    return true;
}

// ── Écritures ───────────────────────────────────────────────────────────────

bool StateBus::submitWrite(const QString &ns, const QString &key,
                           const QVariant &value)
{
    if (ns.isEmpty() || key.isEmpty()) {
        emit writeRejected(ns, key, kCodeInvalidArgs, false);
        return false;
    }

    // Hôte ou solo : application autoritaire immédiate.
    if (!m_active || m_isHost) {
        const QString code = applyAuthoritative(ns, key, value, false);
        if (!code.isEmpty()) {
            emit writeRejected(ns, key, code, false);
            return false;
        }
        return true;
    }

    // Client : pré-contrôle local (rejet à la source, D35) puis intention
    // routée vers l'hôte. PAS d'application optimiste — la valeur revient par
    // le delta autoritatif de l'hôte.
    const int vbytes = valueSizeBytes(value);
    if (vbytes < 0) {
        emit writeRejected(ns, key, kCodeNotSerializable, false);
        return false;
    }
    const QString sizeCode = checkSizeQuotas(ns, key, vbytes);
    if (!sizeCode.isEmpty()) {
        emit writeRejected(ns, key, sizeCode, false);
        return false;
    }
    const int wireBytes = entrySizeBytes(key, vbytes);
    if (!consumePeerBudget(m_localPlayerId, wireBytes)) {
        emit writeRejected(ns, key, kCodeQuota, false);
        return false;
    }

    QJsonObject entry{
        { QStringLiteral("ns"),  ns },
        { QStringLiteral("key"), key },
        { QStringLiteral("value"), QJsonValue::fromVariant(value) },
    };
    QJsonObject payload{
        { QStringLiteral("entries"), QJsonArray{ entry } },
    };
    QString messageId;
    const QByteArray pkt = packEnvelope(kKindIntent, payload, QString(), &messageId);
    Catway::instance()->sendV3Reliable(m_hostPlayerId, pkt, messageId);
    m_outgoingTracked.insert(messageId, kKindIntent);
    ++m_intentsSent;
    emit countersChanged();
    return true;
}

bool StateBus::submitRemove(const QString &ns, const QString &key)
{
    if (ns.isEmpty() || key.isEmpty()) {
        emit writeRejected(ns, key, kCodeInvalidArgs, false);
        return false;
    }

    if (!m_active || m_isHost) {
        const QString code = applyAuthoritative(ns, key, QVariant(), true);
        if (!code.isEmpty()) {
            emit writeRejected(ns, key, code, false);
            return false;
        }
        return true;
    }

    if (!consumePeerBudget(m_localPlayerId, entrySizeBytes(key, 0))) {
        emit writeRejected(ns, key, kCodeQuota, false);
        return false;
    }
    QJsonObject entry{
        { QStringLiteral("ns"),  ns },
        { QStringLiteral("key"), key },
        { QStringLiteral("del"), true },
    };
    QJsonObject payload{
        { QStringLiteral("entries"), QJsonArray{ entry } },
    };
    QString messageId;
    const QByteArray pkt = packEnvelope(kKindIntent, payload, QString(), &messageId);
    Catway::instance()->sendV3Reliable(m_hostPlayerId, pkt, messageId);
    m_outgoingTracked.insert(messageId, kKindIntent);
    ++m_intentsSent;
    emit countersChanged();
    return true;
}

bool StateBus::dropNamespace(const QString &ns)
{
    if (ns.isEmpty()) return false;
    if (m_active && !m_isHost) {
        // Les disparitions structurelles arrivent par les ops d'édition
        // (host-validées), pas par le bus d'état — un client ne droppe pas.
        qWarning() << "[StateBus] dropNamespace côté client ignoré :" << ns;
        return false;
    }
    if (!m_values.contains(ns)) return false;

    const QVariantMap dropped = m_values.take(ns);
    for (auto it = dropped.constBegin(); it != dropped.constEnd(); ++it) {
        const QString ck = compositeKey(ns, it.key());
        m_totalBytes -= m_entryBytes.take(ck);
    }
    m_nsBytes.remove(ns);
    m_seqState.dropKeysWithPrefix(ns + QLatin1Char('/'));
    // Purge des deltas en attente du namespace (ils décriraient des clés mortes).
    for (auto it = m_pendingDeltas.begin(); it != m_pendingDeltas.end();) {
        if (it.value().ns == ns) it = m_pendingDeltas.erase(it);
        else ++it;
    }
    emit namespaceDropped(ns);

    // Changement structurel → snapshot immédiat (D35), qui porte les
    // disparitions (clés absentes → drop côté client).
    if (m_active && m_isHost)
        broadcastSnapshot(QStringLiteral("structural"), QString());
    return true;
}

void StateBus::notifyStructuralChange()
{
    if (!m_active || !m_isHost) return;
    broadcastSnapshot(QStringLiteral("structural"), QString());
}

void StateBus::requestStateSnapshot()
{
    if (!m_active || m_isHost || m_hostPlayerId.isEmpty()) return;
    if (m_snapshotRequestPending) return;
    if (!Catway::instance()->playerById(m_hostPlayerId)) return;

    QString messageId;
    const QByteArray pkt = packEnvelope(kKindRequestSnapshot, QJsonObject(),
                                        QString(), &messageId);
    Catway::instance()->sendV3Reliable(m_hostPlayerId, pkt, messageId);
    m_outgoingTracked.insert(messageId, kKindRequestSnapshot);
    m_snapshotRequestPending = true;
    qDebug() << "[StateBus] CLIENT → RequestStateSnapshot envoyé";
}

// ── Lecture ─────────────────────────────────────────────────────────────────

QVariant StateBus::value(const QString &ns, const QString &key) const
{
    return m_values.value(ns).value(key);
}

bool StateBus::contains(const QString &ns, const QString &key) const
{
    const auto it = m_values.constFind(ns);
    return it != m_values.constEnd() && it->contains(key);
}

QVariantMap StateBus::namespaceValues(const QString &ns) const
{
    return m_values.value(ns);
}

QStringList StateBus::namespaces() const
{
    return m_values.keys();
}

QString StateBus::localStateHash() const
{
    // Hash D39 : JSON canonique (QJsonDocument::Compact trie les clés) de
    // l'état complet {ns: {clé: valeur}}. Les valeurs sont normalisées JSON à
    // l'écriture (applyAuthoritative) → hash identique hôte/client à état égal.
    QJsonObject root;
    for (auto it = m_values.constBegin(); it != m_values.constEnd(); ++it)
        root.insert(it.key(), QJsonObject::fromVariantMap(it.value()));
    return V3Envelope::computePayloadHash(root);
}

// ── Cœur autoritatif ────────────────────────────────────────────────────────

QString StateBus::applyAuthoritative(const QString &ns, const QString &key,
                                     const QVariant &value, bool isRemove)
{
    if (ns.isEmpty() || key.isEmpty()) return kCodeInvalidArgs;

    const QString ck = compositeKey(ns, key);

    if (isRemove) {
        if (!contains(ns, key)) return QString(); // no-op silencieux
        const quint64 seq = m_seqState.nextSeq(ck); // tombstone séquencé :
        // la clé reste suivie → un delta retardataire (seq plus ancienne)
        // ne peut pas ressusciter la valeur.
        eraseValue(ns, key);
        emit valueRemoved(ns, key, seq);
        if (m_active && m_isHost)
            queueDelta(ns, key, QVariant(), true, seq);
        return QString();
    }

    const int vbytes = valueSizeBytes(value);
    if (vbytes < 0) return kCodeNotSerializable;
    const QString sizeCode = checkSizeQuotas(ns, key, vbytes);
    if (!sizeCode.isEmpty()) return sizeCode;

    // Normalisation JSON : la valeur stockée est celle qui voyagera sur le
    // fil — indispensable pour un hash de divergence D39 comparable.
    const QVariant normalized = QJsonValue::fromVariant(value).toVariant();

    // No-op : valeur strictement inchangée → ni séquence, ni delta, ni signal
    // (garde anti-boucle réactive, doc v3/05 §4).
    if (contains(ns, key) && m_values.value(ns).value(key) == normalized)
        return QString();

    const quint64 seq = m_seqState.nextSeq(ck);
    storeValue(ns, key, normalized);
    emit valueApplied(ns, key, normalized, seq);
    if (m_active && m_isHost)
        queueDelta(ns, key, normalized, false, seq);
    return QString();
}

void StateBus::queueDelta(const QString &ns, const QString &key,
                          const QVariant &value, bool isRemove, quint64 seq)
{
    // Coalescence LWW dans le batch : une clé n'apparaît qu'une fois par
    // flush, la dernière écriture gagne → 30 Hz max par (ns, clé).
    PendingDelta d;
    d.ns = ns;
    d.key = key;
    d.value = value;
    d.isRemove = isRemove;
    d.seq = seq;
    m_pendingDeltas.insert(compositeKey(ns, key), d);
    if (!m_flushTimer.isActive())
        m_flushTimer.start();
}

void StateBus::onFlushTimerFired()
{
    if (!m_active || !m_isHost) { m_flushTimer.stop(); m_pendingDeltas.clear(); return; }
    if (m_pendingDeltas.isEmpty()) { m_flushTimer.stop(); return; }

    QJsonArray entries;
    for (const PendingDelta &d : std::as_const(m_pendingDeltas)) {
        QJsonObject entry{
            { QStringLiteral("ns"),  d.ns },
            { QStringLiteral("key"), d.key },
            { QStringLiteral("seq"), static_cast<double>(d.seq) },
        };
        if (d.isRemove) entry.insert(QStringLiteral("del"), true);
        else            entry.insert(QStringLiteral("value"),
                                     QJsonValue::fromVariant(d.value));
        entries.append(entry);
    }
    const int count = m_pendingDeltas.size();
    m_pendingDeltas.clear();
    m_flushTimer.stop();

    // Classe supersedable (D35) : broadcast reliable simple, PAS de suivi B2 —
    // un delta perdu attend le prochain snapshot de réparation.
    const QByteArray pkt = packEnvelope(
        kKindDelta, QJsonObject{{ QStringLiteral("entries"), entries }});
    Catway::instance()->broadcastReliable(pkt);
    m_deltasSent += count;
    m_deltasSinceRepair += count;
    emit countersChanged();

    if (m_deltasSinceRepair >= MEOW_STATEBUS_REPAIR_DELTA_COUNT)
        broadcastSnapshot(QStringLiteral("repair"), QString());
}

void StateBus::onRepairTimerFired()
{
    if (!m_active || !m_isHost) return;
    broadcastSnapshot(QStringLiteral("repair"), QString());
}

QJsonObject StateBus::buildSnapshotPayload(const QString &reason) const
{
    QJsonArray entries;
    for (auto nsIt = m_values.constBegin(); nsIt != m_values.constEnd(); ++nsIt) {
        for (auto it = nsIt->constBegin(); it != nsIt->constEnd(); ++it) {
            entries.append(QJsonObject{
                { QStringLiteral("ns"),  nsIt.key() },
                { QStringLiteral("key"), it.key() },
                { QStringLiteral("value"), QJsonValue::fromVariant(it.value()) },
                { QStringLiteral("seq"), static_cast<double>(
                      m_seqState.lastSeq(compositeKey(nsIt.key(), it.key()))) },
            });
        }
    }
    return QJsonObject{
        { QStringLiteral("reason"),      reason },
        { QStringLiteral("stateHash"),   localStateHash() },
        { QStringLiteral("entries"),     entries },
    };
}

void StateBus::broadcastSnapshot(const QString &reason, const QString &targetPeerId)
{
    if (!m_active || !m_isHost) return;

    // Les deltas en attente sont subsumés par le snapshot (état + séquences
    // complets) : inutile de les envoyer après coup.
    m_pendingDeltas.clear();
    m_flushTimer.stop();
    m_deltasSinceRepair = 0;

    QJsonObject payload = buildSnapshotPayload(reason);
    payload.insert(QStringLiteral("snapshotSeq"),
                   static_cast<double>(++m_snapshotSeqOut));

    const QByteArray pkt = packEnvelope(kKindSnapshot, payload);
    if (targetPeerId.isEmpty()) {
        Catway::instance()->broadcastReliable(pkt);
    } else {
        PlayerNetwork *peer = Catway::instance()->playerById(targetPeerId);
        if (!peer) {
            qWarning() << "[StateBus] snapshot ciblé : pair introuvable" << targetPeerId;
            return;
        }
        Catway::instance()->sendReliableToPlayer(peer, pkt);
    }
    ++m_snapshotsSent;
    emit countersChanged();
}

void StateBus::sendReject(const QString &peerId, const QString &ns,
                          const QString &key, const QString &code,
                          const QString &correlationId)
{
    // Classe commit (verdict de l'hôte) : suivi B2 — le client DOIT apprendre
    // le rejet ({code, retryable:false} remonté tel quel à l'IA, D35).
    QJsonObject payload{
        { QStringLiteral("ns"),        ns },
        { QStringLiteral("key"),       key },
        { QStringLiteral("code"),      code },
        { QStringLiteral("retryable"), false },
    };
    QString messageId;
    const QByteArray pkt = packEnvelope(kKindReject, payload, correlationId,
                                        &messageId);
    Catway::instance()->sendV3Reliable(peerId, pkt, messageId);
    ++m_rejectsEmitted;
    emit countersChanged();
}

// ── Réception ───────────────────────────────────────────────────────────────

void StateBus::onReliableReceived(const QString &senderId, const QByteArray &data)
{
    if (!m_active) return;
    if (!V3Protocol::isV3Packet(data)) return; // trafic V2 (game/editor/physics)

    V3MessageType::Value type;
    V3Envelope envelope;
    if (!V3Protocol::unpack(data, type, envelope)) return;
    if (!envelope.kind.startsWith(QLatin1String("state."))) return; // autre famille V3
    if (envelope.sessionId != m_sessionId) return;
    if (!envelope.verifyPayloadHash()) {
        qWarning() << "[StateBus] payload corrompu (hash) de" << senderId
                   << "kind =" << envelope.kind << "— drop";
        return;
    }

    if (m_isHost) {
        if (envelope.kind == kKindIntent) {
            handleIntent(senderId, envelope.payload, envelope.messageId, data.size());
        } else if (envelope.kind == kKindHello) {
            qDebug() << "[StateBus] HOST ← Hello de" << senderId << "→ snapshot ciblé";
            broadcastSnapshot(QStringLiteral("hello"), senderId);
        } else if (envelope.kind == kKindRequestSnapshot) {
            qDebug() << "[StateBus] HOST ← RequestStateSnapshot de" << senderId;
            broadcastSnapshot(QStringLiteral("request"), senderId);
        }
        return;
    }

    // Client : seule l'autorité (hôte) produit deltas / snapshots / rejets.
    if (senderId != m_hostPlayerId) return;
    if (envelope.kind == kKindDelta)         handleDelta(envelope.payload);
    else if (envelope.kind == kKindSnapshot) handleSnapshot(envelope.payload);
    else if (envelope.kind == kKindReject)   handleReject(envelope.payload);
}

void StateBus::handleIntent(const QString &senderId, const QJsonObject &payload,
                            const QString &messageId, int packetBytes)
{
    ++m_intentsReceived;
    emit countersChanged();

    // Plafond de débit par pair (~64 KB/s, fenêtre glissante 1 s). Dépassement
    // = rejet en bloc, non-retryable (D35 : jamais de troncature silencieuse).
    if (!consumePeerBudget(senderId, packetBytes)) {
        const QJsonArray entries = payload.value(QStringLiteral("entries")).toArray();
        const QJsonObject first = entries.isEmpty() ? QJsonObject()
                                                    : entries.first().toObject();
        sendReject(senderId,
                   first.value(QStringLiteral("ns")).toString(),
                   first.value(QStringLiteral("key")).toString(),
                   kCodeQuota, messageId);
        qWarning() << "[StateBus] HOST : débit dépassé pour" << senderId
                   << "— intention rejetée (quota_exceeded)";
        return;
    }

    const QJsonArray entries = payload.value(QStringLiteral("entries")).toArray();
    for (const QJsonValue &v : entries) {
        const QJsonObject entry = v.toObject();
        const QString ns  = entry.value(QStringLiteral("ns")).toString();
        const QString key = entry.value(QStringLiteral("key")).toString();
        const bool isRemove = entry.value(QStringLiteral("del")).toBool(false);
        const QVariant value = entry.value(QStringLiteral("value")).toVariant();

        // LWW séquencé : ordre d'arrivée autoritatif, séquence allouée à
        // l'acceptation. Le delta coalescé repart vers tous les pairs (y
        // compris l'auteur, qui applique alors sa propre écriture).
        const QString code = applyAuthoritative(ns, key, value, isRemove);
        if (!code.isEmpty())
            sendReject(senderId, ns, key, code, messageId);
    }
}

void StateBus::handleDelta(const QJsonObject &payload)
{
    const QJsonArray entries = payload.value(QStringLiteral("entries")).toArray();
    m_deltasReceived += entries.size();
    emit countersChanged();

    for (const QJsonValue &v : entries) {
        const QJsonObject entry = v.toObject();
        const QString ns  = entry.value(QStringLiteral("ns")).toString();
        const QString key = entry.value(QStringLiteral("key")).toString();
        if (ns.isEmpty() || key.isEmpty()) continue;
        const quint64 seq = static_cast<quint64>(
            entry.value(QStringLiteral("seq")).toDouble());

        // Drop de l'ancien (B3) : seule une séquence strictement plus récente
        // s'applique. Un trou de séquence attend le prochain snapshot — jamais
        // de retransmission (D35).
        if (m_seqState.offer(compositeKey(ns, key), seq) != V3SupersedeVerdict::Applied)
            continue;

        if (entry.value(QStringLiteral("del")).toBool(false)) {
            eraseValue(ns, key);
            emit valueRemoved(ns, key, seq);
        } else {
            const QVariant value = entry.value(QStringLiteral("value")).toVariant();
            storeValue(ns, key, value);
            emit valueApplied(ns, key, value, seq);
        }
    }
}

void StateBus::handleSnapshot(const QJsonObject &payload)
{
    ++m_snapshotsReceived;
    emit countersChanged();

    const QString reason = payload.value(QStringLiteral("reason")).toString();
    if (reason == QLatin1String("request") || reason == QLatin1String("hello"))
        m_snapshotRequestPending = false;

    const QJsonArray entries = payload.value(QStringLiteral("entries")).toArray();

    // Socle de séquences du snapshot (B3) — capture AVANT fusion des
    // dernières séquences locales, pour ne pas régresser un delta déjà reçu
    // plus récent que la capture du snapshot.
    V3StateSnapshot snap;
    snap.snapshotSeq = static_cast<quint64>(
        payload.value(QStringLiteral("snapshotSeq")).toDouble());
    QHash<QString, quint64> preLocalSeq;
    for (const QJsonValue &v : entries) {
        const QJsonObject entry = v.toObject();
        const QString ck = compositeKey(entry.value(QStringLiteral("ns")).toString(),
                                        entry.value(QStringLiteral("key")).toString());
        const quint64 seq = static_cast<quint64>(
            entry.value(QStringLiteral("seq")).toDouble());
        snap.keySeqs.insert(ck, seq);
        preLocalSeq.insert(ck, m_seqState.lastSeq(ck));
    }

    if (!m_seqState.applySnapshot(snap)) {
        qDebug() << "[StateBus] snapshot obsolète (seq" << snap.snapshotSeq
                 << "<= dernier appliqué) — ignoré";
        return;
    }

    // 1) Clés locales absentes du snapshot = supprimées côté hôte (couvre les
    //    disparitions structurelles). On les oublie aussi du tracker : une
    //    éventuelle re-création repartira sur le socle du prochain snapshot.
    const QStringList localNs = m_values.keys();
    for (const QString &ns : localNs) {
        const QStringList keys = m_values.value(ns).keys();
        bool nsEmptied = false;
        for (const QString &key : keys) {
            const QString ck = compositeKey(ns, key);
            if (snap.keySeqs.contains(ck)) continue;
            eraseValue(ns, key);
            m_seqState.dropKey(ck);
            emit valueRemoved(ns, key, snap.snapshotSeq);
            nsEmptied = !m_values.contains(ns);
        }
        if (nsEmptied)
            emit namespaceDropped(ns);
    }

    // 2) Valeurs du snapshot : appliquées sauf si un delta local est déjà PLUS
    //    récent que la capture (fusion max du tracker → on garde le local).
    for (const QJsonValue &v : entries) {
        const QJsonObject entry = v.toObject();
        const QString ns  = entry.value(QStringLiteral("ns")).toString();
        const QString key = entry.value(QStringLiteral("key")).toString();
        if (ns.isEmpty() || key.isEmpty()) continue;
        const QString ck = compositeKey(ns, key);
        const quint64 seq = snap.keySeqs.value(ck);
        if (seq < preLocalSeq.value(ck)) continue; // delta local plus récent
        const QVariant value = entry.value(QStringLiteral("value")).toVariant();
        if (contains(ns, key) && m_values.value(ns).value(key) == value)
            continue; // déjà à jour, pas de réveil inutile
        storeValue(ns, key, value);
        emit valueApplied(ns, key, value, seq);
    }

    emit snapshotApplied(reason);

    // 3) D39 : hash de divergence. Après application, l'état local doit être
    //    celui de l'hôte — sauf si un delta local conservé (plus récent) a été
    //    supplanté entre-temps côté hôte, ou en cas de bug. Un resync est
    //    demandé, SAUF si ce snapshot répondait déjà à un resync (anti-boucle :
    //    on attendra le prochain snapshot de réparation).
    const QString hostHash = payload.value(QStringLiteral("stateHash")).toString();
    if (!hostHash.isEmpty()) {
        const QString local = localStateHash();
        if (local != hostHash) {
            emit divergenceDetected(hostHash, local);
            if (reason != QLatin1String("request") && !m_snapshotRequestPending) {
                qWarning() << "[StateBus] divergence D39 détectée (local" << local
                           << "≠ hôte" << hostHash << ") → RequestStateSnapshot";
                requestStateSnapshot();
            }
        }
    }
}

void StateBus::handleReject(const QJsonObject &payload)
{
    emit writeRejected(payload.value(QStringLiteral("ns")).toString(),
                       payload.value(QStringLiteral("key")).toString(),
                       payload.value(QStringLiteral("code")).toString(),
                       payload.value(QStringLiteral("retryable")).toBool(false));
}

// ── Slots réseau annexes ────────────────────────────────────────────────────

void StateBus::onPlayerTimedOut(const QString &playerId)
{
    m_peerBudgets.remove(playerId);
    // La perte de l'hôte (migration) est orchestrée au-dessus (checkpoint D37,
    // T4-3) : le bus ne décide rien ici.
    if (m_active && !m_isHost && playerId == m_hostPlayerId)
        qWarning() << "[StateBus] hôte" << playerId
                   << "en timeout — en attente d'une migration (D37)";
}

void StateBus::onV3MessageFailed(const QString &playerId, const QString &messageId,
                                 const QString &reason)
{
    const auto it = m_outgoingTracked.constFind(messageId);
    if (it == m_outgoingTracked.constEnd()) return; // pas un message du bus
    const QString kind = it.value();
    m_outgoingTracked.erase(it);

    qWarning() << "[StateBus] échec définitif" << kind << "vers" << playerId
               << "(" << reason << ")";
    if (!m_active || m_isHost) return;

    if (kind == kKindHello) {
        m_helloRetryTimer.start(); // re-tentera quand l'hôte redeviendra joignable
    } else if (kind == kKindRequestSnapshot) {
        m_snapshotRequestPending = false; // le prochain repair re-déclenchera si besoin
    }
    // kKindIntent : l'écriture est perdue — l'état local n'a jamais été muté
    // (pas d'optimisme), le producteur peut re-soumettre.
}

// ── Quotas D35 ──────────────────────────────────────────────────────────────

int StateBus::valueSizeBytes(const QVariant &value)
{
    const QJsonValue jv = QJsonValue::fromVariant(value);
    if (jv.isUndefined()) return -1;
    // QObject*, handles, types non JSON → fromVariant produit null alors que
    // la source ne l'était pas : non sérialisable (doc v3/05 §4).
    if (jv.isNull() && !value.isNull() && value.isValid()) return -1;
    const QJsonArray probe{ jv };
    return static_cast<int>(
        QJsonDocument(probe).toJson(QJsonDocument::Compact).size()) - 2; // "[]"
}

int StateBus::entrySizeBytes(const QString &key, int valueBytes)
{
    // Clé UTF-8 + valeur sérialisée + marge fixe de structure JSON.
    return static_cast<int>(key.toUtf8().size()) + valueBytes + 8;
}

QString StateBus::checkSizeQuotas(const QString &ns, const QString &key,
                                  int valueBytes) const
{
    if (valueBytes > MEOW_STATEBUS_MAX_VALUE_BYTES) return kCodeQuota;
    const int newEntry = entrySizeBytes(key, valueBytes);
    const int oldEntry = m_entryBytes.value(compositeKey(ns, key), 0);
    if (m_nsBytes.value(ns, 0) - oldEntry + newEntry > MEOW_STATEBUS_MAX_NS_BYTES)
        return kCodeQuota;
    if (m_totalBytes - oldEntry + newEntry > MEOW_STATEBUS_MAX_SESSION_BYTES)
        return kCodeQuota;
    return QString();
}

bool StateBus::consumePeerBudget(const QString &peerId, int bytes)
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    auto &window = m_peerBudgets[peerId]; // (débutFenêtre, octets consommés)
    if (now - window.first >= 1000) {
        window.first = now;
        window.second = 0;
    }
    if (window.second + bytes > MEOW_STATEBUS_MAX_PEER_BYTES_PER_SEC)
        return false;
    window.second += bytes;
    return true;
}

// ── Miroir local ────────────────────────────────────────────────────────────

void StateBus::storeValue(const QString &ns, const QString &key,
                          const QVariant &value)
{
    const QString ck = compositeKey(ns, key);
    const int newBytes = entrySizeBytes(key, qMax(0, valueSizeBytes(value)));
    const int oldBytes = m_entryBytes.value(ck, 0);
    m_values[ns].insert(key, value);
    m_entryBytes.insert(ck, newBytes);
    m_nsBytes[ns] += newBytes - oldBytes;
    m_totalBytes  += newBytes - oldBytes;
}

void StateBus::eraseValue(const QString &ns, const QString &key)
{
    const auto nsIt = m_values.find(ns);
    if (nsIt == m_values.end()) return;
    if (nsIt->remove(key) == 0) return;
    const QString ck = compositeKey(ns, key);
    const int oldBytes = m_entryBytes.take(ck);
    m_nsBytes[ns] -= oldBytes;
    m_totalBytes  -= oldBytes;
    if (nsIt->isEmpty()) {
        m_values.erase(nsIt);
        m_nsBytes.remove(ns);
    }
}

// ── Enveloppe B1 ────────────────────────────────────────────────────────────

QByteArray StateBus::packEnvelope(const QString &kind, const QJsonObject &payload,
                                  const QString &correlationId,
                                  QString *messageIdOut)
{
    const V3Envelope envelope = V3Envelope::create(
        m_sessionId, m_localPlayerId, kind, ++m_envelopeSeqOut, payload,
        correlationId);
    if (messageIdOut) *messageIdOut = envelope.messageId;
    return V3Protocol::pack(envelope);
}
