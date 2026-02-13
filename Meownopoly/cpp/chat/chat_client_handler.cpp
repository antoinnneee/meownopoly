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
    bool isTextFile = processedText.startsWith("FILE:");
    QString fileExtension;
    if (isTextFile) {
        int firstColon = processedText.indexOf(':', 3);
        if (firstColon > 3)
            fileExtension = processedText.mid(3, firstColon - 3);
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
    }
}



void ChatClient::handleError(const QJsonObject &payload) {
    QString code = payload["code"].toString();
    QString message = payload["message"].toString();
    if (code == "KEY_ROTATION_REQUIRED") {
        Logger::instance()->info("Server requires key rotation; publishing new key.", "ChatClient");
        m_retryPending = true;
        publishNewKey();
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

        // Retry pending message if any
        if (m_retryPending && !m_pendingMessage.isEmpty()) {
            Logger::instance()->debug(QString("Retrying pending message with new Key Version %1").arg(m_currentKeyVersion), "ChatClient");
            QString msg = m_pendingMessage;
            m_retryPending = false;
            m_pendingMessage.clear();
            sendMessage(msg);
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
    Logger::instance()->debug("Received sessions list", "ChatClient");

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
        sessionMap["name"] = session["session_id"].toString(); // Utilis� pour l'affichage
        sessionMap["sessionId"] = session["session_id"].toString();
        sessionMap["players"] = session["player_count"].toInt();
        sessionMap["maxPlayers"] = session["max_players"].toInt();
        sessionMap["hostNickname"] = session["host_nickname"].toString();
        sessionMap["onlineCount"] = session["online_count"].toInt();
        sessionMap["status"] = session["status"].toString();
        sessionMap["createdAt"] = session["created_at"].toString();

        m_availableSessions.append(sessionMap);
    }

    Logger::instance()->debug(QString("Sessions list updated: %1 sessions").arg(m_availableSessions.size()), "ChatClient");
    emit availableSessionsChanged();
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
            if (version > m_currentKeyVersion) {
                m_currentKeyVersion = version;
            }
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

    // Nos propres messages sont déjà affichés de façon optimiste : ne pas les ré-ajouter
    if (senderId == m_playerId)
        return;

    QtConcurrent::run([this, payload]() {
        QString senderId = payload["sender_id"].toString();
        QString senderNickname = payload["sender_nickname"].toString();
        QByteArray cipher = QByteArray::fromBase64(payload["payload"].toString().toUtf8());
        QByteArray nonce = QByteArray::fromBase64(payload["nonce"].toString().toUtf8());
        QString ts = messageTimestamp(payload);
        int keyVersion = payload["key_version"].toInt();
        bool isEphemeral = payload["ephemeral"].toBool();

        if (!m_sessionKeys.contains(keyVersion)) {
            Logger::instance()->warn(QString("Key version %1 missing in memory! Reloading keys from DB...").arg(keyVersion), "ChatClient");
            loadAndDecryptSessionKeys();
        }
        QByteArray plain = decryptMessagePayload(cipher, nonce, keyVersion);
        if (plain.isEmpty()) {
            QStringList avail;
            for (int k : m_sessionKeys.keys()) avail << QString::number(k);
            Logger::instance()->warn(QString("FAILED to decrypt message. Missing Key Version: %1 (Available: %2)").arg(keyVersion).arg(avail.join(", ")), "ChatClient");
            plain = "[Encrypted Message - Missing Key]";
        }
        QString text = QString::fromUtf8(plain);

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

void ChatClient::handleNewCommand(const QJsonObject &payload) {
    QString senderId = payload["sender_id"].toString();
    QByteArray cipher = QByteArray::fromBase64(payload["payload"].toString().toUtf8());
    QByteArray nonce = QByteArray::fromBase64(payload["nonce"].toString().toUtf8());
    int keyVersion = payload["key_version"].toInt();

    if (!m_sessionKeys.contains(keyVersion)) {
        Logger::instance()->warn(QString("Key version %1 missing for command! Reloading...").arg(keyVersion), "ChatClient");
        loadAndDecryptSessionKeys();
    }
    QByteArray plain = decryptMessagePayload(cipher, nonce, keyVersion);
    if (plain.isEmpty()) {
        Logger::instance()->warn(QString("FAILED to decrypt command from %1 - Missing Key Version: %2").arg(senderId).arg(keyVersion), "ChatClient");
        return;
    }

    QString commandType;
    QJsonObject data;
    if (ChatCommandHelper::parseCommand(QString::fromUtf8(plain), commandType, data)) {
        Logger::instance()->debug(QString("Received command %1 from %2").arg(commandType).arg(senderId), "ChatClient");

        if (commandType == "PING") {
            Logger::instance()->debug(QString("Auto-responding with PONG to %1").arg(senderId), "ChatClient");
            sendCommand("PONG", data, senderId);
        } else if (commandType == "PONG") {
            qint64 sentTs = data["timestamp"].toVariant().toLongLong();
            qint64 now = QDateTime::currentMSecsSinceEpoch();
            Logger::instance()->debug(QString("Received PONG from %1 Roundtrip: %2 ms").arg(senderId).arg(now - sentTs), "ChatClient");
        }

        emit commandReceived(senderId, commandType, data);
    }
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
