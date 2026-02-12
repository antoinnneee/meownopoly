#include "chat_client.h"
#include "chat_image_provider.h"
#include <QJsonDocument>
#include <QDebug>
#include <QImage>
#include <QBuffer>
#include <QFileInfo>
#include <QUrl>
#include <QDataStream>
#include <QClipboard>
#include <QGuiApplication>
#include <QDateTime>
#include <QtConcurrent>


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
        qDebug() << "[ChatClient] Server requires key rotation; publishing new key.";
        m_retryPending = true;
        publishNewKey();
    } else {
        qWarning() << "[ChatClient] Server error:" << code << message;
        emit errorOccurred(message);
    }
}

void ChatClient::handleKeyUpdate(const QJsonObject &payload) {
    if (m_lockKey.isEmpty()) {
        qWarning() << "[ChatClient] Cannot handle key update: LockKey not derived (missing password?)";
        return;
    }

    QString keyPkgBase64 = payload["key_package"].toString();
    QString nonceBase64 = payload["nonce"].toString();
    if (nonceBase64.isEmpty())
        nonceBase64 = payload["key_nonce"].toString();
    int version = payload["version"].toInt(); // Server MUST send version

    if (!keyPkgBase64.isEmpty() && !nonceBase64.isEmpty()) {
        qDebug() << "[ChatClient] Key update received (Version" << version << ")";
        QByteArray keyPkg = QByteArray::fromBase64(keyPkgBase64.toUtf8());
        QByteArray nonce = QByteArray::fromBase64(nonceBase64.toUtf8());

        // 1. Decrypt with LockKey to get the actual SessionKey
        QByteArray sessionKey = ChatCrypto::decrypt(keyPkg, m_lockKey, nonce);

        if (sessionKey.isEmpty()) {
            qCritical() << "[ChatClient] Failed to decrypt received key package! Wrong password?";
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
            qDebug() << "[ChatClient] Retrying pending message with new Key Version" << m_currentKeyVersion;
            QString msg = m_pendingMessage;
            m_retryPending = false;
            m_pendingMessage.clear();
            sendMessage(msg);
        }
    }
}

void ChatClient::handleNewParticipant(const QJsonObject &payload) {
    QString playerId = payload["player_id"].toString();
    qDebug() << "[ChatClient] New participant joined:" << playerId << "; publishing new session key is required.";

    // Add to local participants list if not already present
    bool found = false;
    for (const QVariant &v : m_participants) {
        if (v.toMap()["player_id"].toString() == playerId) {
            found = true;
            break;
        }
    }
    if (!found) {
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
    qDebug() << "[ChatClient] Participant left:" << playerId;

    for (int i = 0; i < m_participants.size(); ++i) {
        if (m_participants[i].toMap()["player_id"].toString() == playerId) {
            m_participants.removeAt(i);
            break;
        }
    }

    emit participantsChanged();
    emit participantLeft(playerId);
}

void ChatClient::handleParticipantsList(const QJsonObject &payload) {
    int count = payload["count"].toInt();
    QJsonArray participantsArray = payload["participants"].toArray();

    qDebug() << "[ChatClient] Received participants list:" << count << "participant(s)";

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
    qDebug() << "[ChatClient] Received sessions list";

    m_availableSessions.clear();

    QJsonArray sessions = payload["sessions"].toArray();
    int total = payload["total"].toInt();
    int limit = payload["limit"].toInt();
    bool limited = payload["limited"].toBool();

    if (limited) {
        qWarning() << "[ChatClient] Sessions list is limited:" << sessions.size() << "/" << total;
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

    qDebug() << "[ChatClient] Sessions list updated:" << m_availableSessions.size() << "sessions" << m_availableSessions;
    emit availableSessionsChanged();
}


void ChatClient::handleInitSession(const QJsonObject &payload) {
    qDebug() << "[ChatClient] Received init session.";

    // Process keys from server (encrypted with lock key; only we can decrypt with password)
    QJsonArray keysArray = payload["keys"].toArray();
    qDebug() << "[ChatClient] Received" << keysArray.size() << "keys from server";
    int serverVersion = payload["current_version"].toInt();
    qDebug() << "[ChatClient] Server version:" << serverVersion;
    qDebug() << "[ChatClient] Local version:" << m_currentKeyVersion;

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
            qWarning() << "[ChatClient] Failed to decrypt key package version" << version << "(wrong password?)";
        }
    }

    const bool newJoiner = payload["new_joiner"].toBool();
    if (newJoiner) {
        qDebug() << "[ChatClient] New joiner: waiting for KEY_UPDATE (no old keys, no history).";
    } else if (m_sessionKeys.isEmpty()) {
        qDebug() << "[ChatClient] No keys yet (new session). Generating new key.";
        publishNewKey();
    } else {
        qDebug() << "[ChatClient] Existing keys found. Using latest Version" << m_currentKeyVersion;
        if (serverVersion > m_currentKeyVersion) {
            qDebug() << "[ChatClient] Server had newer version (" << serverVersion << "); key(s) processed above. If still missing, publishing new key to resync.";
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
            QString ts = msg["server_timestamp"].toString();

            m_db.saveMessage(m_sessionId, senderId, senderNickname, cipher, nonce, ts, msg["key_version"].toInt());

            // Decrypt for UI
            int keyVersion = msg["key_version"].toInt(); // Should be present
            QByteArray plain;
            if (m_sessionKeys.contains(keyVersion)) {
                plain = ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
            } else {
                plain = "[Encrypted Message - Missing Key]";
            }

            QString text = QString::fromUtf8(plain);
            if (text.startsWith("data:image/")) {
                QVariantMap placeholder;
                placeholder["sender"] = senderId;
                placeholder["senderNickname"] = senderNickname;
                placeholder["text"] = "Chargement de l'image...";
                placeholder["isImage"] = false; // Fix: Keep false to avoid QML Image source errors
                placeholder["isTextFile"] = false;
                placeholder["timestamp"] = ts;
                placeholder["isLoading"] = true;
                m_messages.append(placeholder);
                decodeImageAsync(senderId, text, ts);
                continue;
            }

            QString processedText = processMessageText(text);

            // Detect if it's a text file
            bool isTextFile = processedText.startsWith("FILE:");
            QString fileExtension;
            if (isTextFile) {
                // Extract extension from format: ??FILE:ext:filename
                int firstColon = processedText.indexOf(':', 7); // After "??FILE:"
                if (firstColon > 7) {
                    fileExtension = processedText.mid(7, firstColon - 7);
                }
            }

            QVariantMap message;
            message["sender"] = senderId;
            message["senderNickname"] = senderNickname;
            message["text"] = processedText;
            message["isImage"] = processedText.startsWith("image://");
            message["isTextFile"] = isTextFile;
            message["fileExtension"] = fileExtension;
            message["timestamp"] = ts;
            m_messages.append(message);
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
        QString ts = payload["timestamp"].toString();


        // Decrypt for UI
        int keyVersion = payload["key_version"].toInt();

        if (!m_sessionKeys.contains(keyVersion)) {
            qWarning() << "[ChatClient] Key version" << keyVersion << "missing in memory! Reloading keys from DB...";
            loadAndDecryptSessionKeys();
        }

        QByteArray plain;
        if (m_sessionKeys.contains(keyVersion)) {
            plain = ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
        } else {
            qWarning() << "[ChatClient] FAILED to decrypt message. Missing Key Version:" << keyVersion
                       << "Available versions:" << m_sessionKeys.keys();
            plain = "[Encrypted Message - Missing Key]";
        }

        QString text = QString::fromUtf8(plain);
        if (text.startsWith("data:image/")) {
            qDebug() << "image process start:";
            QVariantMap placeholder;
            placeholder["sender"] = senderId;
            placeholder["senderNickname"] = senderNickname;
            placeholder["text"] = "Chargement de l'image...";
            placeholder["isImage"] = false; // Fix: Keep false to avoid QML Image source errors
            placeholder["isTextFile"] = false;
            placeholder["timestamp"] = ts;
            placeholder["isLoading"] = true;
            m_messages.append(placeholder);
            emit messagesChanged();
            decodeImageAsync(senderId, text, ts);
            qDebug() << "image process concurrent run:";
            return;
        }

        QString processedText = processMessageText(text);

        // Detect if it's a text file
        bool isTextFile = processedText.startsWith("FILE:");
        QString fileExtension;
        if (isTextFile) {
            int firstColon = processedText.indexOf(':', 7);
            if (firstColon > 7) {
                fileExtension = processedText.mid(7, firstColon - 7);
            }
        }

        QVariantMap msg;
        msg["sender"] = senderId;
        msg["senderNickname"] = senderNickname;
        msg["text"] = processedText;
        msg["isImage"] = processedText.startsWith("image://");
        msg["isTextFile"] = isTextFile;
        msg["fileExtension"] = fileExtension;
        msg["timestamp"] = ts;
        msg["ephemeral"] = payload["ephemeral"].toBool();
        // m_messages.append(msg);
        // emit messagesChanged();
        // Return to main thread to send the message via WebSocket
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
        qWarning() << "[ChatClient] Key version" << keyVersion << "missing for command! Reloading...";
        loadAndDecryptSessionKeys();
    }

    if (m_sessionKeys.contains(keyVersion)) {
        QByteArray plain = ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
        if (plain.isEmpty()) {
            qWarning() << "[ChatClient] Failed to decrypt command from" << senderId;
            return;
        }

        QString commandType;
        QJsonObject data;
        if (ChatCommandHelper::parseCommand(QString::fromUtf8(plain), commandType, data)) {
            qDebug() << "[ChatClient] Received command" << commandType << "from" << senderId;

            if (commandType == "PING") {
                qDebug() << "[ChatClient] Auto-responding with PONG to" << senderId;
                sendCommand("PONG", data, senderId);
            } else if (commandType == "PONG") {
                qint64 sentTs = data["timestamp"].toVariant().toLongLong();
                qint64 now = QDateTime::currentMSecsSinceEpoch();
                qDebug() << "[ChatClient] Received PONG from" << senderId << "Roundtrip:" << (now - sentTs) << "ms";
            }

            emit commandReceived(senderId, commandType, data);
        }
    } else {
        qWarning() << "[ChatClient] FAILED to decrypt command. Missing Key Version:" << keyVersion;
    }
}


void ChatClient::handleHistoryResult(const QJsonObject &payload) {
    qDebug() << "[ChatClient] Received history result from server";
    QJsonArray historyArray = payload["history"].toArray();

    if (historyArray.isEmpty()) {
        qDebug() << "[ChatClient] No history messages received";
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
        QString ts = msg["server_timestamp"].toString();

        m_db.saveMessage(m_sessionId, senderId, senderNickname, cipher, nonce, ts, msg["key_version"].toInt());

        int keyVersion = msg["key_version"].toInt();
        QByteArray plain;
        if (m_sessionKeys.contains(keyVersion)) {
            plain = ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
        } else {
            plain = "[Encrypted History]";
        }

        QString text = QString::fromUtf8(plain);
        if (text.startsWith("data:image/")) {
            QVariantMap placeholder;
            placeholder["sender"] = senderId;
            placeholder["senderNickname"] = senderNickname;
            placeholder["text"] = "Chargement de l'image...";
            placeholder["isImage"] = false; // Fix: Keep false
            placeholder["isTextFile"] = false;
            placeholder["timestamp"] = ts;
            placeholder["isLoading"] = true;
            olderMessages.append(placeholder);
            decodeImageAsync(senderId, text, ts);
            continue;
        }

        QString processedText = processMessageText(text);

        // Detect if it's a text file
        bool isTextFile = processedText.startsWith("??FILE:");
        QString fileExtension;
        if (isTextFile) {
            int firstColon = processedText.indexOf(':', 7);
            if (firstColon > 7) {
                fileExtension = processedText.mid(7, firstColon - 7);
            }
        }

        QVariantMap message;
        message["sender"] = senderId;
        message["senderNickname"] = senderNickname;
        message["text"] = processedText;
        message["isImage"] = processedText.startsWith("image://");
        message["isTextFile"] = isTextFile;
        message["fileExtension"] = fileExtension;
        message["timestamp"] = ts;
        olderMessages.append(message);
    }

    // Prepend older messages to the current list
    for (int i = olderMessages.size() - 1; i >= 0; --i) {
        m_messages.prepend(olderMessages[i]);
    }

    emit messagesChanged();
    qDebug() << "[ChatClient] Loaded" << historyArray.size() << "messages from server history";
}

void ChatClient::handleHistoryCleared() {
    qDebug() << "[ChatClient] History cleared by server event";

    // Clear local DB
    m_db.clearMessages(m_sessionId);

    // Clear UI model
    m_messages.clear();
    emit messagesChanged();
}
