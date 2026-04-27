#include "chat_client.h"
#include "chat_image_provider.h"
#include "tools/logger.h"
#include <QJsonDocument>
#include <QImage>
#include <QBuffer>
#include <QFileInfo>
#include <QUrl>
#include <QDataStream>
#include <QClipboard>
#include <QGuiApplication>
#include <QDateTime>
#include <QtConcurrent>

// --- Helpers (réduction de la redondance) ---

QByteArray ChatClient::decryptMessagePayload(const QByteArray &cipher, const QByteArray &nonce, int keyVersion) {
    if (m_sessionKeys.contains(keyVersion))
        return ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
    return QByteArray();
}

QString ChatClient::messageTimestamp(const QJsonObject &msg) {
    QString ts = msg["server_timestamp"].toString();
    if (ts.isEmpty())
        ts = msg["timestamp"].toString();
    return ts;
}

QVariantMap ChatClient::buildMessageMapFromDecryptedText(const QString &senderId, const QString &senderNickname,
        const QString &text, const QString &ts, bool isEphemeral, bool *outIsImagePlaceholder) {
    if (outIsImagePlaceholder)
        *outIsImagePlaceholder = false;

    if (text.startsWith("data:image/")) {
        if (outIsImagePlaceholder)
            *outIsImagePlaceholder = true;
        QVariantMap placeholder;
        placeholder["sender"] = senderId;
        placeholder["senderNickname"] = senderNickname;
        placeholder["text"] = "Chargement de l'image...";
        placeholder["isImage"] = false;
        placeholder["isTextFile"] = false;
        placeholder["timestamp"] = ts;
        placeholder["isLoading"] = true;
        return placeholder;
    }

    QString processedText = processMessageText(text);
    bool isTextFile = processedText.startsWith("📄FILE:");
    QString fileExtension;
    if (isTextFile) {
        int firstColon = processedText.indexOf(':', 7);
        if (firstColon > 7)
            fileExtension = processedText.mid(7, firstColon - 7);
    }
    QVariantMap message;
    message["sender"] = senderId;
    message["senderNickname"] = senderNickname;
    message["text"] = processedText;
    message["isImage"] = processedText.startsWith("image://");
    message["isTextFile"] = isTextFile;
    message["fileExtension"] = fileExtension;
    message["timestamp"] = ts;
    message["ephemeral"] = isEphemeral;
    return message;
}

int ChatClient::indexOfParticipant(const QString &playerId) const {
    for (int i = 0; i < m_participants.size(); ++i) {
        if (m_participants[i].toMap()["player_id"].toString() == playerId)
            return i;
    }
    return -1;
}

// --- Handlers principaux ---

void ChatClient::onTextMessageReceived(const QString &message) {
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();
    QJsonObject payload = obj["payload"].toObject();

    if (type == "INIT_SESSION") {
        handleInitSession(payload);
    } else if (type == "SESSION_CREATED") {
        handleSessionCreated(payload);
    } else if (type == "SESSIONS_LIST") {
        handleSessionsList(payload);
    } else if (type == "NEW_MESSAGE") {
        handleNewMessage(payload);
    } else if (type == "HISTORY_RESULT") {
        handleHistoryResult(payload);
    } else if (type == "KEY_UPDATE") {
        handleKeyUpdate(payload);
    } else if (type == "NEW_PARTICIPANT") {
        handleNewParticipant(payload);
    } else if (type == "PARTICIPANT_LEFT") {
        handleParticipantLeft(payload);
    } else if (type == "PARTICIPANTS_LIST") {
        handleParticipantsList(payload);
    } else if (type == "NEW_COMMAND") {
        handleNewCommand(payload);
    } else if (type == "ERROR") {
        handleError(payload);
    } else if (type == "HISTORY_CLEARED") {
        handleHistoryCleared();
    } else if (type == "KICKED") {
        handleKicked(payload);
    } else if (type == "PARTICIPANT_KICKED") {
        handleParticipantKicked(payload);
    } else if (type == "SESSION_ENDED") {
        handleSessionEnded(payload);
    } else if (type == "LEFT_SESSION") {
        handleLeftSession(payload);
    } else if (type == "SERVER_RESET") {
        handleServerReset(payload);
    } else if (type == "SESSION_CREATED_BROADCAST") {
        handleSessionCreatedBroadcast(payload);
    } else if (type == "SESSION_RENAMED") {
        handleSessionRenamed(payload);
    } else if (type == "HOST_CHANGED") {
        handleHostChanged(payload);
    } else if (type == "SESSION_DELETED") {
        handleSessionDeleted(payload);
    } else {
        Logger::instance()->warn(QString("Unhandled server message type: %1").arg(type), "ChatClient");
    }
}

void ChatClient::resetSessionState() {
    m_sessionId.clear();
    m_password.clear();
    m_lockKey.clear();
    m_passwordHash.clear();
    m_sessionKeys.clear();
    m_currentKeyVersion = 0;
    m_messages.clear();
    m_participants.clear();
    m_pendingMessages.clear();
    m_retryPending = false;
    emit sessionIdChanged();
    emit messagesChanged();
    emit participantsChanged();
}

void ChatClient::handleKicked(const QJsonObject &payload) {
    const QString sessionId = payload["session_id"].toString();
    const QString reason = payload["reason"].toString();
    Logger::instance()->info(QString("Kicked from session %1: %2").arg(sessionId, reason), "ChatClient");
    emit kicked(sessionId, reason);
    resetSessionState();
}

void ChatClient::handleParticipantKicked(const QJsonObject &payload) {
    const QString sessionId = payload["session_id"].toString();
    const QString playerId  = payload["player_id"].toString();
    Logger::instance()->info(QString("Participant %1 kicked from %2").arg(playerId, sessionId), "ChatClient");

    int idx = indexOfParticipant(playerId);
    if (idx >= 0) {
        m_participants.removeAt(idx);
        emit participantsChanged();
    }
    emit participantKicked(sessionId, playerId);
}

void ChatClient::handleSessionEnded(const QJsonObject &payload) {
    const QString sessionId = payload["session_id"].toString();
    const QString reason    = payload["reason"].toString();
    Logger::instance()->info(QString("Session %1 ended: %2").arg(sessionId, reason), "ChatClient");
    emit sessionEnded(sessionId, reason);
    resetSessionState();
}

void ChatClient::handleLeftSession(const QJsonObject &payload) {
    const QString sessionId = payload["session_id"].toString();
    Logger::instance()->debug(QString("Server acknowledged LEAVE for session %1").arg(sessionId), "ChatClient");
    emit leftSession(sessionId);
    resetSessionState();
}

void ChatClient::handleServerReset(const QJsonObject &payload) {
    const QString message = payload["message"].toString();
    Logger::instance()->warn(QString("Server reset notification: %1").arg(message), "ChatClient");
    emit serverReset(message);
    resetSessionState();
    // Refresh disponible sessions list (now empty)
    m_availableSessions.clear();
    emit availableSessionsChanged();
}

void ChatClient::handleSessionDeleted(const QJsonObject &payload) {
    const QString sessionId = payload["session_id"].toString();
    Logger::instance()->debug(QString("Session %1 deleted on server").arg(sessionId),
                              "ChatClient");
    bool changed = false;
    for (int i = m_availableSessions.size() - 1; i >= 0; --i) {
        if (m_availableSessions[i].toMap().value("sessionId").toString() == sessionId) {
            m_availableSessions.removeAt(i);
            changed = true;
            break;
        }
    }
    if (changed) emit availableSessionsChanged();
}

void ChatClient::handleSessionRenamed(const QJsonObject &payload) {
    const QString sessionId   = payload["session_id"].toString();
    const QString sessionName = payload["session_name"].toString();
    Logger::instance()->debug(
        QString("Session %1 renamed to \"%2\"").arg(sessionId, sessionName),
        "ChatClient");

    // Mise à jour in-place de availableSessions (évite un round-trip).
    bool changed = false;
    for (int i = 0; i < m_availableSessions.size(); ++i) {
        QVariantMap m = m_availableSessions[i].toMap();
        if (m.value("sessionId").toString() == sessionId) {
            m.insert("name", sessionName);
            m_availableSessions[i] = m;
            changed = true;
            break;
        }
    }
    if (changed) emit availableSessionsChanged();

    emit sessionRenamed(sessionId, sessionName);
}

void ChatClient::handleHostChanged(const QJsonObject &payload) {
    const QString sessionId = payload["session_id"].toString();
    const QString hostId    = payload["host_player_id"].toString();
    Logger::instance()->debug(
        QString("Session %1 host changed to %2").arg(sessionId, hostId),
        "ChatClient");

    // Mise à jour in-place du hostId dans availableSessions. Le nickname
    // sera rafraîchi au prochain LIST_SESSIONS (round-trip acceptable ici,
    // mais on peut essayer de trouver le nickname dans les participants si
    // c'est notre session courante).
    bool changed = false;
    for (int i = 0; i < m_availableSessions.size(); ++i) {
        QVariantMap m = m_availableSessions[i].toMap();
        if (m.value("sessionId").toString() == sessionId) {
            m.insert("hostId", hostId);
            // Tenter de deviner le nickname depuis les participants locaux.
            if (sessionId == m_sessionId) {
                int idx = indexOfParticipant(hostId);
                if (idx >= 0) {
                    m.insert("hostNickname",
                             m_participants[idx].toMap().value("nickname").toString());
                }
            }
            m_availableSessions[i] = m;
            changed = true;
            break;
        }
    }
    if (changed) emit availableSessionsChanged();

    emit hostChanged(sessionId, hostId);
}

void ChatClient::handleSessionCreatedBroadcast(const QJsonObject &payload) {
    const QString sessionId   = payload["session_id"].toString();
    const QString sessionName = payload["session_name"].toString();
    Logger::instance()->debug(QString("Another client created session %1 (%2)").arg(sessionId, sessionName), "ChatClient");
    emit sessionCreatedBroadcast(sessionId, sessionName);
    // Optionnel: rafraîchir automatiquement la liste pour le lobby.
    if (m_connected)
        requestSessionsList();
}



void ChatClient::handleError(const QJsonObject &payload) {
    QString code = payload["code"].toString();
    QString message = payload["message"].toString();
    if (code == "KEY_ROTATION_REQUIRED") {
        Logger::instance()->info("Server requires key rotation; publishing new key.", "ChatClient");
        m_retryPending = true;
        publishNewKey();
    } else if (code == "SESSION_NOT_FOUND") {
        Logger::instance()->warn("Join failed: session does not exist.", "ChatClient");
        emit errorOccurred("La session demandée n'existe pas.");
    } else if (code == "INVALID_PASSWORD") {
        Logger::instance()->warn("Join failed: invalid password.", "ChatClient");
        emit errorOccurred("Le mot de passe pour la session est invalide.", ErrorSession::INVALID_PASSWORD);
    } else {
        Logger::instance()->warn(QString("Server error: %1 %2").arg(code).arg(message), "ChatClient");
        emit errorOccurred(message);
    }
}

void ChatClient::handleKeyUpdate(const QJsonObject &payload) {
    if (m_lockKey.isEmpty()) {
        Logger::instance()->warn("Cannot handle key update: LockKey not derived (missing password?)", "ChatClient");
        return;
    }

    QString keyPkgBase64 = payload["key_package"].toString();
    QString nonceBase64 = payload["nonce"].toString();
    if (nonceBase64.isEmpty())
        nonceBase64 = payload["key_nonce"].toString();
    int version = payload["version"].toInt(); // Server MUST send version

    if (!keyPkgBase64.isEmpty() && !nonceBase64.isEmpty()) {
        Logger::instance()->debug(QString("Key update received (Version %1)").arg(version), "ChatClient");
        QByteArray keyPkg = QByteArray::fromBase64(keyPkgBase64.toUtf8());
        QByteArray nonce = QByteArray::fromBase64(nonceBase64.toUtf8());

        // 1. Decrypt with LockKey to get the actual SessionKey
        QByteArray sessionKey = ChatCrypto::decrypt(keyPkg, m_lockKey, nonce);

        if (sessionKey.isEmpty()) {
            Logger::instance()->error("Failed to decrypt received key package! Wrong password?", "ChatClient");
            return;
        }

        // 2. Save encrypted blob to DB (for persistence)
        m_db.saveSessionKey(m_sessionId, version, keyPkg, nonce);

        // 3. Store PLAIN key in memory
        m_sessionKeys.insert(version, sessionKey);
        m_currentKeyVersion = version;

        emit messagesChanged(); // Reprocess messages if needed

        // Retry queued messages (FIFO) si une rotation était attendue.
        if (m_retryPending && !m_pendingMessages.isEmpty()) {
            Logger::instance()->debug(QString("Retrying %1 pending message(s) with new Key Version %2")
                                          .arg(m_pendingMessages.size()).arg(m_currentKeyVersion), "ChatClient");
            const QStringList toRetry = m_pendingMessages;
            m_pendingMessages.clear();
            m_retryPending = false;
            for (const QString &msg : toRetry) {
                sendMessage(msg);
            }
        }
    }
}

void ChatClient::handleNewParticipant(const QJsonObject &payload) {
    QString playerId = payload["player_id"].toString();
    Logger::instance()->info(QString("New participant joined: %1; publishing new session key is required.").arg(playerId), "ChatClient");

    if (indexOfParticipant(playerId) < 0) {
        QVariantMap participant;
        participant["player_id"] = playerId;
        participant["player_nickname"] = payload["player_nickname"].toString();
        participant["status"] = "online";
        m_participants.append(participant);
        emit participantsChanged();
        emit participantJoined(playerId, payload["player_nickname"].toString());
    }

    publishNewKey();
}

void ChatClient::handleParticipantLeft(const QJsonObject &payload) {
    QString playerId = payload["player_id"].toString();
    Logger::instance()->info(QString("Participant left: %1").arg(playerId), "ChatClient");

    int idx = indexOfParticipant(playerId);
    if (idx >= 0)
        m_participants.removeAt(idx);

    emit participantsChanged();
    emit participantLeft(playerId);
}

void ChatClient::handleParticipantsList(const QJsonObject &payload) {
    int count = payload["count"].toInt();
    QJsonArray participantsArray = payload["participants"].toArray();

    Logger::instance()->debug(QString("Received participants list: %1 participant(s)").arg(count), "ChatClient");

    m_participants.clear();
    for (const QJsonValue &val : participantsArray) {
        QJsonObject p = val.toObject();
        QVariantMap participant;
        participant["player_id"] = p["player_id"].toString();
        participant["player_nickname"] = p["player_nickname"].toString();
        participant["status"] = p["status"].toString();
        participant["is_host"] = p["is_host"].toBool();
        m_participants.append(participant);
    }

    emit participantsChanged();
}

void ChatClient::handleSessionsList(const QJsonObject &payload) {
    // Logger::instance()->debug("Received sessions list", "ChatClient");

    m_availableSessions.clear();

    QJsonArray sessions = payload["sessions"].toArray();
    int total = payload["total"].toInt();
    int limit = payload["limit"].toInt();
    bool limited = payload["limited"].toBool();

    if (limited) {
        Logger::instance()->warn(QString("Sessions list is limited: %1/%2").arg(sessions.size()).arg(total), "ChatClient");
    }

    for (const QJsonValue &val : sessions) {
        QJsonObject session = val.toObject();

        QVariantMap sessionMap;
        QString sessionName = session["session_name"].toString();
        sessionMap["name"] = sessionName.isEmpty() ? session["session_id"].toString() : sessionName;
        sessionMap["sessionId"] = session["session_id"].toString();
        sessionMap["players"] = session["player_count"].toInt();
        sessionMap["maxPlayers"] = session["max_players"].toInt();
        sessionMap["hostId"] = session["host_id"].toString();
        sessionMap["hostNickname"] = session["host_nickname"].toString();
        sessionMap["onlineCount"] = session["online_count"].toInt();
        sessionMap["status"] = session["status"].toString();
        sessionMap["createdAt"] = session["created_at"].toString();

        m_availableSessions.append(sessionMap);
    }

    // Logger::instance()->debug(QString("Sessions list updated: %1 sessions").arg(m_availableSessions.size()), "ChatClient");
    emit availableSessionsChanged();
}


void ChatClient::handleSessionCreated(const QJsonObject &payload) {
    const QString sessionId   = payload["session_id"].toString();
    const QString sessionName = payload["session_name"].toString();
    Logger::instance()->info(
        QString("Session created on server: %1 (%2). Joining now...").arg(sessionId).arg(sessionName),
        "ChatClient");

    m_sessionKeys.clear();
    m_currentKeyVersion = 0;

    joinSession();

    emit sessionCreated(sessionId, sessionName);
}

void ChatClient::handleInitSession(const QJsonObject &payload) {
    Logger::instance()->debug("Received init session.", "ChatClient");

    // Process keys from server (encrypted with lock key; only we can decrypt with password)
    QJsonArray keysArray = payload["keys"].toArray();
    Logger::instance()->debug(QString("Received %1 keys from server").arg(keysArray.size()), "ChatClient");
    int serverVersion = payload["current_version"].toInt();
    Logger::instance()->debug(QString("Server version: %1, Local version: %2").arg(serverVersion).arg(m_currentKeyVersion), "ChatClient");

    for (const QJsonValue &val : keysArray) {
        QJsonObject k = val.toObject();
        QString keyPkgBase64 = k["key_package"].toString();
        QString nonceBase64 = k["nonce"].toString();
        if (nonceBase64.isEmpty())
            nonceBase64 = k["key_nonce"].toString(); // Server DB sends key_nonce
        int version = k["version"].toInt();
        if (keyPkgBase64.isEmpty() || nonceBase64.isEmpty()) continue;
        QByteArray keyPkg = QByteArray::fromBase64(keyPkgBase64.toUtf8());
        QByteArray nonce = QByteArray::fromBase64(nonceBase64.toUtf8());
        QByteArray sessionKey = ChatCrypto::decrypt(keyPkg, m_lockKey, nonce);
        if (!sessionKey.isEmpty()) {
            m_db.saveSessionKey(m_sessionId, version, keyPkg, nonce);
            m_sessionKeys.insert(version, sessionKey);
            m_currentKeyVersion = version;
        } else {
            Logger::instance()->warn(QString("Failed to decrypt key package version %1 (wrong password?)").arg(version), "ChatClient");
        }
    }

    const bool newJoiner = payload["new_joiner"].toBool();
    if (newJoiner) {
        Logger::instance()->debug("New joiner: waiting for KEY_UPDATE (no old keys, no history).", "ChatClient");
    } else if (m_sessionKeys.isEmpty()) {
        Logger::instance()->debug("No keys yet (new session). Generating new key.", "ChatClient");
        publishNewKey();
    } else {
        Logger::instance()->debug(QString("Existing keys found. Using latest Version %1").arg(m_currentKeyVersion), "ChatClient");
        if (serverVersion > m_currentKeyVersion) {
            Logger::instance()->debug(QString("Server had newer version (%1); key(s) processed above. If still missing, publishing new key to resync.").arg(serverVersion), "ChatClient");
            publishNewKey();
        }
    }

    // Process server history if provided
    QJsonArray historyArray = payload["history"].toArray();
    if (!historyArray.isEmpty()) {
        m_messages.clear();
        for (const QJsonValue &val : historyArray) {
            QJsonObject msg = val.toObject();
            QString senderId = msg["sender_id"].toString();
            QString senderNickname = msg["sender_nickname"].toString();
            QByteArray cipher = QByteArray::fromBase64(msg["payload"].toString().toUtf8());
            QByteArray nonce = QByteArray::fromBase64(msg["nonce"].toString().toUtf8());
            QString ts = messageTimestamp(msg);
            int keyVersion = msg["key_version"].toInt();

            m_db.saveMessage(m_sessionId, senderId, senderNickname, cipher, nonce, ts, keyVersion);

            QByteArray plain = decryptMessagePayload(cipher, nonce, keyVersion);
            if (plain.isEmpty())
                plain = "[Encrypted Message - Missing Key]";
            QString text = QString::fromUtf8(plain);

            bool isImagePlaceholder = false;
            QVariantMap entry = buildMessageMapFromDecryptedText(senderId, senderNickname, text, ts, false, &isImagePlaceholder);
            m_messages.append(entry);
            if (isImagePlaceholder)
                decodeImageAsync(senderId, text, ts);
        }
        emit messagesChanged();
    } else {
        loadHistory();
    }
}

void ChatClient::handleNewMessage(const QJsonObject &payload) {
    const QString senderId = payload["sender_id"].toString();
    const bool ephemeral = payload["ephemeral"].toBool();

    // Messages éphémères (privés / unicast) ne sont pas enregistrés dans l'historique
    if (!ephemeral) {
        m_db.saveMessage(m_sessionId, senderId, payload["sender_nickname"].toString(), QByteArray::fromBase64(payload["payload"].toString().toUtf8()),
                         QByteArray::fromBase64(payload["nonce"].toString().toUtf8()), payload["timestamp"].toString(), payload["key_version"].toInt());
    }

    // Nos propres messages sont déjà affichés de façon optimiste : ne pas les ré-ajouter.
    // En revanche on en profite pour dépiler la file d'attente FIFO des messages envoyés
    // (utile uniquement si une rotation de clé survient avant l'ack).
    if (senderId == m_playerId) {
        if (!m_pendingMessages.isEmpty())
            m_pendingMessages.removeFirst();
        return;
    }

    // THREAD SAFETY: tout ce qui touche m_sessionKeys et m_db doit rester sur la GUI thread.
    // On capture la clé nécessaire ICI (thread principal), puis on délègue uniquement le
    // déchiffrement (CPU) à QtConcurrent. Pour l'UI on revient en queued connection.
    const int keyVersion = payload["key_version"].toInt();

    if (!m_sessionKeys.contains(keyVersion)) {
        Logger::instance()->warn(QString("Key version %1 missing in memory! Reloading keys from DB on GUI thread...").arg(keyVersion), "ChatClient");
        // Rechargement DB sur la GUI thread (m_db est lié à ce thread, pas thread-safe).
        loadAndDecryptSessionKeys();
    }

    // Snapshot par valeur de la clé requise (seul ce qui est nécessaire à la lambda).
    const QByteArray sessionKey = m_sessionKeys.value(keyVersion);
    QStringList availableKeys;
    if (sessionKey.isEmpty()) {
        for (int k : m_sessionKeys.keys()) availableKeys << QString::number(k);
    }

    // Utilise m_chatPool pour permettre à ~ChatClient d'attendre la fin de la tâche
    // (waitForDone) et éviter un use-after-free quand l'app se ferme alors qu'un
    // déchiffrement est en cours.
    m_chatPool.start([this, payload, keyVersion, sessionKey, availableKeys]() {
        const QString senderId = payload["sender_id"].toString();
        const QString senderNickname = payload["sender_nickname"].toString();
        const QByteArray cipher = QByteArray::fromBase64(payload["payload"].toString().toUtf8());
        const QByteArray nonce = QByteArray::fromBase64(payload["nonce"].toString().toUtf8());
        const QString ts = messageTimestamp(payload);
        const bool isEphemeral = payload["ephemeral"].toBool();

        QByteArray plain;
        if (!sessionKey.isEmpty()) {
            plain = ChatCrypto::decrypt(cipher, sessionKey, nonce);
        }
        if (plain.isEmpty()) {
            Logger::instance()->warn(QString("FAILED to decrypt message. Missing/invalid Key Version: %1 (Available at dispatch: %2)")
                                         .arg(keyVersion).arg(availableKeys.join(", ")), "ChatClient");
            plain = "[Encrypted Message - Missing Key]";
        }
        const QString text = QString::fromUtf8(plain);

        bool isImagePlaceholder = false;
        QVariantMap msg = buildMessageMapFromDecryptedText(senderId, senderNickname, text, ts, isEphemeral, &isImagePlaceholder);

        if (isImagePlaceholder) {
            Logger::instance()->debug("Image process start", "ChatClient");
            QMetaObject::invokeMethod(this, [this, msg, senderId, text, ts]() {
                m_messages.append(msg);
                emit messagesChanged();
                decodeImageAsync(senderId, text, ts);
            }, Qt::QueuedConnection);
            return;
        }

        QMetaObject::invokeMethod(this, [this, msg]() {
            m_messages.append(msg);
            emit messagesChanged();
        }, Qt::QueuedConnection);
    });
}


void ChatClient::handleHistoryResult(const QJsonObject &payload) {
    Logger::instance()->debug("Received history result from server", "ChatClient");
    QJsonArray historyArray = payload["history"].toArray();

    if (historyArray.isEmpty()) {
        Logger::instance()->debug("No history messages received", "ChatClient");
        return;
    }

    // Process history messages (prepend older messages)
    QVariantList olderMessages;
    for (const QJsonValue &val : historyArray) {
        QJsonObject msg = val.toObject();
        QString senderId = msg["sender_id"].toString();
        QString senderNickname = msg["sender_nickname"].toString();
        QByteArray cipher = QByteArray::fromBase64(msg["payload"].toString().toUtf8());
        QByteArray nonce = QByteArray::fromBase64(msg["nonce"].toString().toUtf8());
        QString ts = messageTimestamp(msg);
        int keyVersion = msg["key_version"].toInt();

        m_db.saveMessage(m_sessionId, senderId, senderNickname, cipher, nonce, ts, keyVersion);

        QByteArray plain = decryptMessagePayload(cipher, nonce, keyVersion);
        if (plain.isEmpty())
            plain = "[Encrypted History]";
        QString text = QString::fromUtf8(plain);

        bool isImagePlaceholder = false;
        QVariantMap entry = buildMessageMapFromDecryptedText(senderId, senderNickname, text, ts, false, &isImagePlaceholder);
        olderMessages.append(entry);
        if (isImagePlaceholder)
            decodeImageAsync(senderId, text, ts);
    }

    // Prepend older messages to the current list
    for (int i = olderMessages.size() - 1; i >= 0; --i) {
        m_messages.prepend(olderMessages[i]);
    }

    emit messagesChanged();
    Logger::instance()->debug(QString("Loaded %1 messages from server history").arg(historyArray.size()), "ChatClient");
}

void ChatClient::handleHistoryCleared() {
    Logger::instance()->debug("History cleared by server event", "ChatClient");

    // Clear local DB
    m_db.clearMessages(m_sessionId);

    // Clear UI model
    m_messages.clear();
    emit messagesChanged();
}
