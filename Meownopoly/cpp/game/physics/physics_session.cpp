#include "physics_session.h"

#include "physics_protocol.h"
#include "physics_world.h"

#include "communication/catway.h"
#include "communication/player_network.h"

#include <QDateTime>
#include <QDebug>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonValue>
#include <QtQml>

#include <cmath>

PhysicsSession *PhysicsSession::m_pThis = nullptr;

// ── Singleton ────────────────────────────────────────────────────────────────

PhysicsSession::PhysicsSession(QObject *parent) : QObject(parent)
{
    m_snapshotTimer.setTimerType(Qt::PreciseTimer);
    connect(&m_snapshotTimer, &QTimer::timeout,
            this, &PhysicsSession::onSnapshotTimerFired);

    // Re-broadcast périodique de la table complète (1 Hz). Couvre :
    //  - late-join : un client qui rejoint reçoit la table sans Hello dédié
    //  - paquets perdus : reliable.io a son propre ACK mais on est ceinture+bretelles
    m_fullTableTimer.setInterval(1000);
    connect(&m_fullTableTimer, &QTimer::timeout, this, [this]() {
        if (m_active && m_isHost) broadcastFullBodyTable();
    });

    // Retry du Hello côté client : tant que l'hôte n'est pas dans Catway
    // (hole punch en cours), on re-tente toutes les 500 ms. Le timer 1 Hz de
    // l'hôte couvre la full table mais PAS le claim — sans Hello, les inputs
    // du client sont rejetés par la garde N1 côté hôte.
    m_helloRetryTimer.setInterval(500);
    connect(&m_helloRetryTimer, &QTimer::timeout, this, [this]() {
        if (!m_active || m_isHost) { m_helloRetryTimer.stop(); return; }
        if (sendHelloToHost()) m_helloRetryTimer.stop();
    });
}

PhysicsSession *PhysicsSession::instance()
{
    if (!m_pThis) m_pThis = new PhysicsSession();
    return m_pThis;
}

QObject *PhysicsSession::qmlInstance(QQmlEngine *, QJSEngine *) { return instance(); }

void PhysicsSession::registerQml()
{
    qmlRegisterSingletonType<PhysicsSession>("Pattounx", 1, 0, "PhysicsSession",
                                             &PhysicsSession::qmlInstance);
}

void PhysicsSession::setSnapshotHz(int hz)
{
    if (hz < 1)   hz = 1;
    if (hz > 240) hz = 240;
    if (m_snapshotHz == hz) return;
    m_snapshotHz = hz;
    if (m_snapshotTimer.isActive()) {
        // qRound : la division entière biaisait la cadence vers le haut
        // (ex. 30 Hz → 33 ms → 30.3 Hz effectifs ; 45 Hz → 22 ms → 45.5).
        m_snapshotTimer.setInterval(qRound(1000.0 / m_snapshotHz));
    }
    emit snapshotHzChanged();
}

void PhysicsSession::setClaimedActorId(const QString &actorId)
{
    if (m_claimedActorId == actorId) return;
    m_claimedActorId = actorId;
    emit claimedActorIdChanged();

    // Nouveau claim → statut re-optimiste jusqu'au verdict (Welcome) de
    // l'hôte. Un `claimAccepted == false` résiduel de l'ancien claim ne
    // décrit plus rien.
    if (!m_claimAccepted) {
        m_claimAccepted = true;
        emit claimAcceptedChanged();
    }

    // Claim changé APRÈS startAsClient : re-notifier l'hôte, sinon il garde
    // l'ancien claim (ou aucun) et les InputUpdate du nouveau claim sont
    // rejetés par sa garde de sécurité.
    if (m_active && !m_isHost && !sendHelloToHost())
        m_helloRetryTimer.start();
}

void PhysicsSession::setPhysicsWorld(QObject *world)
{
    m_world = qobject_cast<PhysicsWorld *>(world);
    if (!m_world)
        qWarning() << "[PhysicsSession] setPhysicsWorld: pointeur invalide";
}

// ── Cycle de vie ────────────────────────────────────────────────────────────

bool PhysicsSession::startAsHost(const QString &localPlayerId)
{
    if (!m_world) {
        qWarning() << "[PhysicsSession] startAsHost: physicsWorld non assigné";
        return false;
    }
    if (m_active) stop();

    m_localPlayerId = localPlayerId;
    m_hostPlayerId.clear();
    m_isHost = true;
    m_active = true;

    connectToCatway();

    // Pump initial des announcements pour la table déjà existante.
    flushPendingAnnouncements();

    m_snapshotTimer.start(qRound(1000.0 / m_snapshotHz));
    m_fullTableTimer.start();

    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit isHostChanged();
    emit activeChanged();
    qDebug() << "[PhysicsSession] HOST start, playerId =" << localPlayerId
             << "snapshotHz =" << m_snapshotHz;
    return true;
}

bool PhysicsSession::startAsClient(const QString &localPlayerId,
                                   const QString &hostPlayerId)
{
    if (!m_world) {
        qWarning() << "[PhysicsSession] startAsClient: physicsWorld non assigné";
        return false;
    }
    if (m_active) stop();

    m_localPlayerId = localPlayerId;
    m_hostPlayerId  = hostPlayerId;
    m_isHost = false;
    m_active = true;

    connectToCatway();

    // Sim locale OFF + buffer remote ON. Côté client, c'est le snapshot de
    // l'hôte qui dicte les positions.
    m_world->setSimulationEnabled(false);
    m_world->setUseRemoteBuffer(true);

    // Hello explicite à l'host : demande la full table d'idIndex sans
    // attendre le timer 1 Hz, et embarque le claim local pour que l'host
    // sache quel actor il ne doit plus pousser localement. Si l'hôte n'est
    // pas encore joignable (hole punch en cours), retry 500 ms — le timer
    // 1 Hz de l'hôte ne couvre pas le claim, seulement la full table.
    if (!sendHelloToHost()) {
        qWarning() << "[PhysicsSession] CLIENT start : host introuvable dans Catway"
                   << hostPlayerId << "— Hello non envoyé, retry armé (500 ms)";
        m_helloRetryTimer.start();
    }

    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit isHostChanged();
    emit activeChanged();
    qDebug() << "[PhysicsSession] CLIENT start, playerId =" << localPlayerId
             << "host =" << hostPlayerId;
    return true;
}

void PhysicsSession::stop()
{
    // Hôte qui part volontairement : prévenir les clients AVANT de couper,
    // sinon ils restent gelés sur le dernier snapshot jusqu'au timeout
    // Catway (~10-30 s). En cas de fermeture d'app, le QML doit laisser le
    // paquet partir (Qt.quit() différé, cf. physics_message_type.h).
    if (m_active && m_isHost) {
        Catway::instance()->broadcastReliable(
            PhysicsProtocol::packJson(PhysicsMessageType::HostLeaving, {}));
        qDebug() << "[PhysicsSession] HOST → HostLeaving broadcasté";
    }

    disconnectFromCatway();
    m_snapshotTimer.stop();
    m_fullTableTimer.stop();
    m_helloRetryTimer.stop();

    if (m_world) {
        if (!m_isHost) {
            // Repasse en local + relance la sim. setUseRemoteBuffer(false)
            // appelle resetNetworkState() en interne (purge table + buffer).
            m_world->setUseRemoteBuffer(false);
            m_world->setSimulationEnabled(true);
        } else {
            // Host : pas de mode remote à toggle, mais on purge quand même
            // pour ne pas réutiliser les idIndex de la session précédente
            // si on relance startAsHost.
            m_world->resetNetworkState();
        }
    }

    m_active = false;
    m_isHost = false;
    m_localPlayerId.clear();
    m_hostPlayerId.clear();
    m_remoteClaims.clear();
    m_combatReqWindows.clear();
    m_lastSentInputs.clear();
    m_snapshotsSent = 0;
    m_snapshotsReceived = 0;
    if (!m_claimAccepted) {
        m_claimAccepted = true; // reset optimiste entre sessions
        emit claimAcceptedChanged();
    }

    emit activeChanged();
    emit isHostChanged();
    emit localPlayerIdChanged();
    emit hostPlayerIdChanged();
    emit snapshotsSentChanged();
    emit snapshotsReceivedChanged();
    qDebug() << "[PhysicsSession] stopped";
}

// ── Connexion Catway ────────────────────────────────────────────────────────

void PhysicsSession::connectToCatway()
{
    Catway *catway = Catway::instance();
    m_reliableConn = connect(catway, &Catway::reliableMessageReceived,
                             this,   &PhysicsSession::onReliableReceived);
    m_timeoutConn  = connect(catway, &Catway::playerTimedOut,
                             this,   &PhysicsSession::onPlayerTimedOut);
}

void PhysicsSession::disconnectFromCatway()
{
    disconnect(m_reliableConn);
    disconnect(m_timeoutConn);
}

bool PhysicsSession::sendHelloToHost()
{
    if (m_hostPlayerId.isEmpty()) return false;
    PlayerNetwork *host = Catway::instance()->playerById(m_hostPlayerId);
    if (!host) return false;

    QJsonObject helloPayload;
    if (!m_claimedActorId.isEmpty())
        helloPayload.insert(QStringLiteral("claim"), m_claimedActorId);
    const QByteArray pkt = PhysicsProtocol::packJson(
        PhysicsMessageType::Hello, helloPayload);
    Catway::instance()->sendReliableToPlayer(host, pkt);
    // Ré-armer la dédup d'inputs : les InputUpdate partis avant ce Hello ont
    // pu être rejetés par l'hôte (claim pas encore enregistré) — un input
    // constant maintenu doit pouvoir repartir même inchangé.
    m_lastSentInputs.clear();
    qDebug() << "[PhysicsSession] CLIENT → Hello envoyé à" << m_hostPlayerId
             << "claim =" << m_claimedActorId;
    return true;
}

// ── Inputs ──────────────────────────────────────────────────────────────────

void PhysicsSession::pushOrSendInput(const QString &actorId, QVector2D input)
{
    if (!m_world) return;
    if (!m_active) {
        m_world->pushInput(actorId, input);
        return;
    }
    if (m_isHost) {
        // Côté hôte : si un client distant a déjà claim cet actor, on
        // ignore le push local — sinon les deux claviers se battent.
        for (auto it = m_remoteClaims.constBegin(); it != m_remoteClaims.constEnd(); ++it) {
            if (it.value() == actorId) return;
        }
        m_world->pushInput(actorId, input);
        return;
    }
    // Client : si le pair a déclaré un actor revendiqué, on filtre tout le
    // reste — sinon on enverrait des inputs concurrents au host pour des
    // actors que d'autres pairs (ou l'host lui-même) contrôlent déjà.
    if (!m_claimedActorId.isEmpty() && actorId != m_claimedActorId) return;
    // Client : envoyer InputUpdate reliable au host.
    if (m_hostPlayerId.isEmpty()) return;
    // Dédup : reliable garantit la livraison, inutile de renvoyer un vecteur
    // identique à chaque frame (60-144 pkts/s pour un input constant). Le
    // cache est purgé à chaque Hello (cf. sendHelloToHost) : les inputs
    // envoyés AVANT l'enregistrement du claim ont été rejetés par l'hôte,
    // il faut pouvoir les ré-émettre même inchangés.
    const auto lastIt = m_lastSentInputs.constFind(actorId);
    if (lastIt != m_lastSentInputs.constEnd() && lastIt.value() == input) return;
    m_lastSentInputs.insert(actorId, input);
    QJsonObject payload{
        { "actorId", actorId },
        { "x", input.x() },
        { "y", input.y() },
    };
    const QByteArray packet = PhysicsProtocol::packJson(
        PhysicsMessageType::InputUpdate, payload);
    PlayerNetwork *host = Catway::instance()->playerById(m_hostPlayerId);
    if (host) Catway::instance()->sendReliableToPlayer(host, packet);
}

// ── Canal combat ────────────────────────────────────────────────────────────

void PhysicsSession::sendCombatRequest(const QVariantMap &payload)
{
    if (!m_active || m_isHost || m_hostPlayerId.isEmpty()) return;
    const QByteArray packet = PhysicsProtocol::packJson(
        PhysicsMessageType::AttackRequest, QJsonObject::fromVariantMap(payload));
    if (PlayerNetwork *host = Catway::instance()->playerById(m_hostPlayerId))
        Catway::instance()->sendReliableToPlayer(host, packet);
}

void PhysicsSession::broadcastCombatEvent(const QVariantMap &payload)
{
    if (!m_active || !m_isHost) return;
    const QByteArray packet = PhysicsProtocol::packJson(
        PhysicsMessageType::CombatEvent, QJsonObject::fromVariantMap(payload));
    Catway::instance()->broadcastReliable(packet);
}

// ── Hôte : broadcast snapshot ───────────────────────────────────────────────

void PhysicsSession::onSnapshotTimerFired()
{
    if (!m_active || !m_isHost || !m_world) return;

    // 1) Sérialise (et synchronise la table d'idIndex côté hôte).
    const QByteArray payload = m_world->serializeSnapshot();
    if (payload.isEmpty()) return;

    // 2) Envoie BodiesAnnounce AVANT le snapshot si delta non vide.
    flushPendingAnnouncements();

    // 3) Broadcast du snapshot (reliable pour Phase 7 — cf. note dans
    //    physics_message_type.h : migration vers raw possible si le budget
    //    bande passante le justifie).
    const QByteArray packet = PhysicsProtocol::packBinary(
        PhysicsMessageType::Snapshot, payload);
    Catway::instance()->broadcastReliable(packet);
    ++m_snapshotsSent;
    if ((m_snapshotsSent & 0x1F) == 0) // throttle log
        emit snapshotsSentChanged();
}

void PhysicsSession::flushPendingAnnouncements()
{
    if (!m_active || !m_isHost || !m_world) return;
    const QVariantMap delta = m_world->takePendingAnnouncements();
    const QVariantMap added = delta.value(QStringLiteral("added")).toMap();
    const QVariantList removed = delta.value(QStringLiteral("removed")).toList();
    if (added.isEmpty() && removed.isEmpty()) return;

    const QJsonObject payload = buildAnnouncePayload(added, removed);
    const QByteArray packet = PhysicsProtocol::packJson(
        PhysicsMessageType::BodiesAnnounce, payload);
    Catway::instance()->broadcastReliable(packet);
    qDebug() << "[PhysicsSession] BodiesAnnounce delta : added =" << added.size()
             << ", removed =" << removed.size();
}

void PhysicsSession::broadcastFullBodyTable()
{
    if (!m_active || !m_isHost || !m_world) return;
    const QVariantMap full = m_world->currentBodyTable();
    if (full.isEmpty()) return; // rien à annoncer
    const QJsonObject payload = buildAnnouncePayload(full, {}, /*fullTable=*/true);
    const QByteArray packet = PhysicsProtocol::packJson(
        PhysicsMessageType::BodiesAnnounce, payload);
    Catway::instance()->broadcastReliable(packet);
}

QJsonObject PhysicsSession::buildAnnouncePayload(const QVariantMap &added,
                                                 const QVariantList &removed,
                                                 bool fullTable)
{
    QJsonObject addedJson;
    for (auto it = added.constBegin(); it != added.constEnd(); ++it)
        addedJson.insert(it.key(), it.value().toString());
    QJsonArray removedJson;
    for (const QVariant &v : removed) removedJson.append(v.toString());
    QJsonObject payload;
    payload.insert(QStringLiteral("added"), addedJson);
    payload.insert(QStringLiteral("removed"), removedJson);
    if (fullTable)
        payload.insert(QStringLiteral("full"), true);
    return payload;
}

void PhysicsSession::sendWelcome(const QString &peerId, bool accepted,
                                 const QString &claim, const QString &takenBy)
{
    QJsonObject payload;
    payload.insert(QStringLiteral("claimAccepted"), accepted);
    payload.insert(QStringLiteral("claim"), claim);
    if (!takenBy.isEmpty())
        payload.insert(QStringLiteral("takenBy"), takenBy);
    const QByteArray pkt = PhysicsProtocol::packJson(
        PhysicsMessageType::Welcome, payload);
    if (PlayerNetwork *peer = Catway::instance()->playerById(peerId))
        Catway::instance()->sendReliableToPlayer(peer, pkt);
}

// ── Réception ───────────────────────────────────────────────────────────────

void PhysicsSession::onReliableReceived(const QString &senderId,
                                        const QByteArray &data)
{
    if (!m_active || !m_world) return;
    PhysicsMessageType::Value type;
    if (!PhysicsProtocol::peekType(data, type)) return; // pas pour nous

    switch (type) {
    case PhysicsMessageType::Snapshot:
        if (!m_isHost && senderId == m_hostPlayerId) {
            m_world->applyRemoteSnapshot(PhysicsProtocol::payloadBytes(data));
            ++m_snapshotsReceived;
            if ((m_snapshotsReceived & 0x1F) == 0)
                emit snapshotsReceivedChanged();
        }
        break;

    case PhysicsMessageType::BodiesAnnounce: {
        // Réservé au client, et seul l'hôte fait autorité sur la table
        // idIndex — un pair tiers pourrait sinon corrompre le décodage des
        // snapshots de tout le monde (même garde que Snapshot/CombatEvent).
        if (m_isHost || senderId != m_hostPlayerId) break;
        QJsonObject payload;
        PhysicsMessageType::Value t;
        if (!PhysicsProtocol::unpackJson(data, t, payload)) break;
        const QJsonObject addedObj = payload.value(QStringLiteral("added")).toObject();
        const QJsonArray  removedArr = payload.value(QStringLiteral("removed")).toArray();
        QVariantMap addedMap;
        for (auto it = addedObj.constBegin(); it != addedObj.constEnd(); ++it)
            addedMap.insert(it.key(), it.value().toString());
        QStringList removed;
        removed.reserve(removedArr.size());
        for (const QJsonValue &v : removedArr) removed.append(v.toString());
        // Full table (re-broadcast 1 Hz, réponse au Hello) : remplacement
        // intégral de la table côté client, cf. applyBodiesAnnounce (N9).
        const bool fullTable = payload.value(QStringLiteral("full")).toBool(false);
        qDebug() << "[PhysicsSession] CLIENT ← BodiesAnnounce de" << senderId
                 << ": added =" << addedMap.size() << ", removed =" << removed.size()
                 << (fullTable ? "(full)" : "(delta)");
        m_world->applyBodiesAnnounce(addedMap, removed, fullTable);
        break;
    }

    case PhysicsMessageType::InputUpdate: {
        if (!m_isHost) break; // réservé à l'hôte
        QJsonObject payload;
        PhysicsMessageType::Value t;
        if (!PhysicsProtocol::unpackJson(data, t, payload)) break;
        const QString actorId = payload.value(QStringLiteral("actorId")).toString();
        if (actorId.isEmpty()) break;
        // Sécurité : seul le client qui a claimé cet acteur (via Hello) peut
        // le piloter — sinon n'importe quel pair peut bouger l'acteur de
        // l'hôte, des autres clients, ou tout body input-driven.
        if (m_remoteClaims.value(senderId) != actorId) {
            static int rejected = 0;
            if ((rejected++ & 0x3F) == 0) {
                qWarning() << "[PhysicsSession] HOST : InputUpdate rejeté —"
                           << senderId << "n'a pas claimé" << actorId
                           << "(Hello perdu ou paquet forgé, " << rejected
                           << "rejets cumulés)";
            }
            break;
        }
        // Sécurité : borner l'input. Un NaN empoisonnerait toute la sim
        // (positions NaN propagées à tous les clients via snapshot) ; une
        // norme > 1 est un speed-hack (l'input est un vecteur directionnel).
        const double xd = payload.value(QStringLiteral("x")).toDouble();
        const double yd = payload.value(QStringLiteral("y")).toDouble();
        if (!std::isfinite(xd) || !std::isfinite(yd)) break;
        QVector2D input(static_cast<float>(xd), static_cast<float>(yd));
        if (input.lengthSquared() > 1.0f) input.normalize();
        m_world->pushInput(actorId, input);
        break;
    }

    case PhysicsMessageType::Hello: {
        // Côté hôte : un client vient de démarrer, lui pousser la full table
        // d'idIndex en point-à-point pour qu'il puisse interpréter les
        // snapshots. On enregistre aussi son claim pour filtrer les pushInput
        // locaux conflictuels.
        if (!m_isHost) break;
        // Valider le sender contre le roster Catway AVANT d'enregistrer le
        // moindre claim — un Hello forgé d'un pair inconnu ne doit pas
        // pouvoir réserver un acteur (et on a de toute façon besoin du peer
        // pour répondre).
        PlayerNetwork *peer = Catway::instance()->playerById(senderId);
        if (!peer) {
            qWarning() << "[PhysicsSession] Hello reçu mais sender hors roster :"
                       << senderId << "— ignoré";
            break;
        }
        QJsonObject helloPayload;
        PhysicsMessageType::Value t;
        QString requestedClaim;
        bool claimAccepted = true;
        QString takenBy;
        if (PhysicsProtocol::unpackJson(data, t, helloPayload)) {
            const QString claim = helloPayload.value(QStringLiteral("claim")).toString();
            requestedClaim = claim;
            const QString previous = m_remoteClaims.value(senderId);
            if (claim != previous) {
                // Arbitrage : premier arrivé, premier servi. Sans ce refus,
                // deux clients claimant le même acteur verraient leurs
                // InputUpdate s'écraser mutuellement à chaque frame.
                for (auto it = m_remoteClaims.constBegin();
                     it != m_remoteClaims.constEnd(); ++it) {
                    if (it.value() == claim && it.key() != senderId) {
                        takenBy = it.key();
                        break;
                    }
                }
                if (!claim.isEmpty() && !takenBy.isEmpty()) {
                    claimAccepted = false;
                    qWarning() << "[PhysicsSession] HOST : claim refusé —"
                               << claim << "déjà pris par" << takenBy
                               << "(demandé par" << senderId << ")";
                } else {
                    // L'acteur précédemment claimé par ce sender est relâché :
                    // neutraliser son dernier input (même logique que N5).
                    if (!previous.isEmpty() && m_world)
                        m_world->pushInput(previous, QVector2D(0.0f, 0.0f));
                    if (claim.isEmpty())
                        m_remoteClaims.remove(senderId); // purge (Hello sans claim)
                    else
                        m_remoteClaims.insert(senderId, claim);
                    emit remoteClaimsChanged();
                    qDebug() << "[PhysicsSession] HOST : claim de" << senderId
                             << ":" << previous << "→" << claim;
                }
            }
        }
        const QVariantMap full = m_world->currentBodyTable();
        const QJsonObject payload = buildAnnouncePayload(full, {}, /*fullTable=*/true);
        const QByteArray pkt = PhysicsProtocol::packJson(
            PhysicsMessageType::BodiesAnnounce, payload);
        Catway::instance()->sendReliableToPlayer(peer, pkt);
        qDebug() << "[PhysicsSession] HOST ← Hello de" << senderId
                 << "→ envoi BodiesAnnounce full table (" << full.size()
                 << "bodies)";
        // Welcome : accusé du Hello + verdict du claim. Sans lui, un claim
        // refusé laissait le client dans le noir (inputs rejetés en silence).
        sendWelcome(senderId, claimAccepted, requestedClaim, takenBy);
        break;
    }

    case PhysicsMessageType::Welcome: {
        if (m_isHost || senderId != m_hostPlayerId) break; // réservé au client
        QJsonObject payload;
        PhysicsMessageType::Value t;
        if (!PhysicsProtocol::unpackJson(data, t, payload)) break;
        const QString claim = payload.value(QStringLiteral("claim")).toString();
        // Welcome périmé (le claim local a changé depuis ce Hello) : ignorer,
        // le Hello du nouveau claim déclenchera son propre Welcome.
        if (claim != m_claimedActorId) break;
        const bool accepted = payload.value(QStringLiteral("claimAccepted")).toBool(true);
        const QString takenBy = payload.value(QStringLiteral("takenBy")).toString();
        if (m_claimAccepted != accepted) {
            m_claimAccepted = accepted;
            emit claimAcceptedChanged();
        }
        if (!accepted) {
            qWarning() << "[PhysicsSession] CLIENT : claim" << claim
                       << "refusé par l'hôte (déjà pris par" << takenBy
                       << ") — les inputs de ce pair seront rejetés";
            emit claimRejected(claim, takenBy);
        } else {
            qDebug() << "[PhysicsSession] CLIENT ← Welcome : claim" << claim
                     << "accepté";
        }
        break;
    }

    case PhysicsMessageType::AttackRequest: {
        if (!m_isHost) break; // réservé à l'hôte (résolution autoritaire)
        QJsonObject payload;
        PhysicsMessageType::Value t;
        if (!PhysicsProtocol::unpackJson(data, t, payload)) break;
        // Whitelist minimale : le payload est relayé tel quel au QML (JSON
        // libre par design), mais on borne au moins aux types connus des
        // contrôleurs (CombatController "attack", GrabController "grab").
        const QString reqType = payload.value(QStringLiteral("type")).toString();
        if (reqType != QLatin1String("attack") && reqType != QLatin1String("grab")) {
            static int unknown = 0;
            if ((unknown++ & 0x3F) == 0) {
                qWarning() << "[PhysicsSession] HOST : AttackRequest de type inconnu"
                           << reqType << "rejeté (sender" << senderId << ","
                           << unknown << "rejets cumulés)";
            }
            break;
        }
        // Rate-limit par sender (fenêtre glissante 1 s) : chaque requête
        // déclenche une résolution QML complète (scan des tiles) — un client
        // fou ou forgé ne doit pas pouvoir saturer l'hôte. 20/s laisse une
        // marge large au gameplay légitime (cooldown d'attaque ≥ 400 ms).
        const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
        auto &window = m_combatReqWindows[senderId];
        if (nowMs - window.first >= 1000) {
            window.first = nowMs;
            window.second = 0;
        }
        if (++window.second > 20) {
            static int throttled = 0;
            if ((throttled++ & 0x3F) == 0) {
                qWarning() << "[PhysicsSession] HOST : AttackRequest de" << senderId
                           << "rate-limité (> 20/s," << throttled
                           << "drops cumulés)";
            }
            break;
        }
        emit combatRequestReceived(senderId, payload.toVariantMap());
        break;
    }

    case PhysicsMessageType::CombatEvent: {
        if (m_isHost || senderId != m_hostPlayerId) break; // réservé au client
        QJsonObject payload;
        PhysicsMessageType::Value t;
        if (!PhysicsProtocol::unpackJson(data, t, payload)) break;
        emit combatEventReceived(payload.toVariantMap());
        break;
    }

    case PhysicsMessageType::HostLeaving:
        // Départ volontaire de l'hôte : même traitement que le timeout,
        // mais immédiat au lieu d'attendre le heartbeat Catway.
        if (!m_isHost && senderId == m_hostPlayerId) {
            qWarning() << "[PhysicsSession] hôte parti (HostLeaving) — retour en sim locale";
            stop();
        }
        break;
    }
}

void PhysicsSession::onPlayerTimedOut(const QString &playerId)
{
    if (!m_active) return;
    if (!m_isHost && playerId == m_hostPlayerId) {
        qWarning() << "[PhysicsSession] hôte perdu (timeout)";
        // Pour Phase 7 : repasse en mode local. La récupération multi-saut
        // (élection, promotion) sera ajoutée au-dessus de l'éditeur collab si
        // nécessaire (cf. EditorSession::promoteToHost).
        stop();
        return;
    }
    if (m_isHost) {
        // Un client est tombé : libère son claim, le host peut re-pousser
        // localement l'actor s'il en a envie. On neutralise d'abord le
        // dernier input reçu — sinon un client qui crash flèche enfoncée
        // laisse son acteur courir dans un mur indéfiniment (le moteur
        // garde la dernière valeur de setBodyInput).
        const QString claimedActor = m_remoteClaims.value(playerId);
        if (!claimedActor.isEmpty() && m_world)
            m_world->pushInput(claimedActor, QVector2D(0.0f, 0.0f));
        if (m_remoteClaims.remove(playerId) > 0) {
            emit remoteClaimsChanged();
            qDebug() << "[PhysicsSession] HOST : claim libéré pour" << playerId
                     << "(input de" << claimedActor << "remis à zéro)";
        }
    }
}
