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

ChatClient::ChatClient(QObject *parent) : QObject(parent) {
    // Initialize database
    m_db.init();

    // Create worker thread
    m_workerThread = new QThread(this);
    m_worker = new ChatWorker();
    m_worker->moveToThread(m_workerThread);

    // Connect worker signals to client slots
    connect(m_worker, &ChatWorker::connected, this, &ChatClient::onConnected);
    connect(m_worker, &ChatWorker::disconnected, this, &ChatClient::onDisconnected);
    connect(m_worker, &ChatWorker::textMessageReceived, this, &ChatClient::onTextMessageReceived);
    connect(m_worker, &ChatWorker::errorOccurred, this, &ChatClient::errorOccurred);

    // Connect client signals to worker slots (cross-thread)
    connect(this, &ChatClient::destroyed, m_worker, &ChatWorker::deleteLater);

    // Start the worker thread
    m_workerThread->start();

    qDebug() << "[ChatClient] Initialized with worker thread";
}

ChatClient::~ChatClient() {
    qDebug() << "[ChatClient] Destructor called";

    // Stop the worker thread
    if (m_workerThread) {
        m_workerThread->quit();
        if (!m_workerThread->wait(3000)) {
            qWarning() << "[ChatClient] Worker thread did not finish in time, terminating";
            m_workerThread->terminate();
            m_workerThread->wait();
        }
    }

    qDebug() << "[ChatClient] Destroyed";
}

void ChatClient::setSessionId(const QString &id) {
    if (m_sessionId != id) {
        m_sessionId = id;
        // Lock key now requires password, defer derivation
        emit sessionIdChanged();
    }
}

void ChatClient::connectToServer(const QString &url) {
    qDebug() << "[ChatClient] Connecting to server:" << url;
    
    // Reset session data on new connection attempt? 
    // For now, we just connect. Session data is handled by connectToSession.

    // Use queued connection to call worker method in worker thread
    QMetaObject::invokeMethod(m_worker, "connectToServer", Qt::QueuedConnection,
                              Q_ARG(QString, url));
}

void ChatClient::connectToSession(const QString &playerId, const QString &password, const QString &nickname) {
    m_playerId = playerId;
    m_nickname = nickname.isEmpty() ? playerId : nickname;
    m_password = password;

    qDebug() << "[ChatClient] Preparing session for player:" << m_playerId;

    // Derive Lock Key from SessionID + Password
    m_lockKey = ChatCrypto::deriveLockKey(m_sessionId, m_password);

    // Load LOCAL keys immediately (Forward Secrecy = no keys from server)
    // Keys in DB are encrypted with lockKey. We must decrypt them for memory usage.
    QMap<int, QByteArray> encryptedKeys = m_db.getSessionKeys(m_sessionId);
    m_sessionKeys.clear();

    qDebug() << "[ChatClient] Loaded" << encryptedKeys.size() << "encrypted keys from local storage";

    for (auto it = encryptedKeys.begin(); it != encryptedKeys.end(); ++it) {
        int version = it.key();
        QByteArray combined = it.value();

        QDataStream stream(combined);
        QByteArray encryptedPkg, nonce;
        stream >> encryptedPkg >> nonce;

        QByteArray plainKey = ChatCrypto::decrypt(encryptedPkg, m_lockKey, nonce);
        if (!plainKey.isEmpty()) {
            m_sessionKeys.insert(version, plainKey);
        } else {
            qWarning() << "[ChatClient] Failed to decrypt session key Version" << version;
        }
    }

    qDebug() << "[ChatClient] Decrypted" << m_sessionKeys.size() << "session keys into memory";

    // Determine current version (max version locally)
    if (!m_sessionKeys.isEmpty()) {
        m_currentKeyVersion = m_sessionKeys.lastKey();
    } else {
        m_currentKeyVersion = 0;
    }

    // If already connected, join immediately
    if (m_connected) {
        // Join session logic
        QJsonObject join;
        join["type"] = "JOIN_SESSION";
        QJsonObject payload;
        payload["session_id"] = m_sessionId;
        payload["player_id"] = m_playerId;
        payload["player_nickname"] = m_nickname;
        join["payload"] = payload;

        sendWebSocketMessage(join);

        // Request participants list right after joining
        requestParticipants();
    }
}

void ChatClient::onConnected() {
    qDebug() << "[ChatClient] Connected to server";
    m_connected = true;
    emit connectedChanged();

    // If we have session data, join automatically (reconnect scenario or connection after setup)
    if (!m_playerId.isEmpty() && !m_sessionId.isEmpty()) {
        qDebug() << "[ChatClient] joining session" << m_sessionId << "as" << m_playerId;
        QJsonObject join;
        join["type"] = "JOIN_SESSION";
        QJsonObject payload;
        payload["session_id"] = m_sessionId;
        payload["player_id"] = m_playerId;
        payload["player_nickname"] = m_nickname;
        join["payload"] = payload;

        sendWebSocketMessage(join);

        // Request participants list right after joining
        requestParticipants();
    }
}

void ChatClient::onDisconnected() {
    qDebug() << "[ChatClient] Disconnected from server";
    m_connected = false;
    m_participants.clear();
    m_pendingMessage.clear();
    m_retryPending = false;
    emit connectedChanged();
    emit participantsChanged();
}

void ChatClient::sendWebSocketMessage(const QJsonObject &message) {
    QString jsonString = QJsonDocument(message).toJson(QJsonDocument::Compact);
    QMetaObject::invokeMethod(m_worker, "sendTextMessage", Qt::QueuedConnection,
                              Q_ARG(QString, jsonString));
}

void ChatClient::onTextMessageReceived(const QString &message) {
    qDebug() << "Received message: TextMessageReceived";
    QJsonDocument doc = QJsonDocument::fromJson(message.toUtf8());
    QJsonObject obj = doc.object();
    QString type = obj["type"].toString();
    QJsonObject payload = obj["payload"].toObject();

    if (type == "INIT_SESSION") {
        handleInitSession(payload);
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
    } else if (type == "SESSIONS_LIST") {
        handleSessionsList(payload);
    } else if (type == "ERROR") {
        handleError(payload);
    } else if (type == "HISTORY_CLEARED") {
        handleHistoryCleared();
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
    qDebug() << "[ChatClient] New participant joined:" << playerId << "; publishing new session key.";

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
        sessionMap["name"] = session["session_id"].toString(); // Utilisé pour l'affichage
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

void ChatClient::requestParticipants() {
    if (!m_connected) {
        qWarning() << "[ChatClient] Cannot request participants: not connected";
        return;
    }

    QJsonObject request;
    request["type"] = "GET_PARTICIPANTS";
    QJsonObject payload;
    payload["session_id"] = m_sessionId;
    request["payload"] = payload;

    sendWebSocketMessage(request);
    qDebug() << "[ChatClient] Requested participants list for session" << m_sessionId;
}

void ChatClient::requestSessionsList() {
    if (!m_connected) {
        qWarning() << "[ChatClient] Cannot request sessions list: not connected";
        return;
    }
    
    qDebug() << "[ChatClient] Requesting sessions list";
    
    QJsonObject msg;
    msg["type"] = "LIST_SESSIONS";
    msg["payload"] = QJsonObject();
    
    sendWebSocketMessage(msg);
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

void ChatClient::publishNewKey() {
    if (m_lockKey.isEmpty()) {
        qWarning() << "[ChatClient] Cannot publish key: LockKey not derived (missing password?)";
        return;
    }
    QByteArray newKey = ChatCrypto::generateRandomKey();
    QByteArray nonce = ChatCrypto::generateNonce();
    QByteArray encryptedPkg = ChatCrypto::encrypt(newKey, m_lockKey, nonce);
    QJsonObject publish;
    publish["type"] = "PUBLISH_KEY";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    p["blob"] = QString(encryptedPkg.toBase64());

    p["nonce"] = QString(nonce.toBase64());
    publish["payload"] = p;
    sendWebSocketMessage(publish);
    qDebug() << "[ChatClient] Published new key. Waiting for KEY_UPDATE.";
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
                // The blob in m_sessionKeys is encrypted with lockKey.
                // We must decrypt the session key first?
                // Wait, m_sessionKeys stored blobs?
                // ChatDatabase::getSessionKeys returns the blob+nonce.
                // We need to unpack and decrypt the session key itself.

                // Optimized approach: m_sessionKeys should store DECRYPTED keys in memory?
                // No, we store Encrypted Blob + Nonce in m_sessionKeys map value?
                // Let's assume m_sessionKeys holds: Version -> [EncryptedKey + Nonce] (as loaded from DB)

                // We need to decrypt the session key to use it.
                // Doing this for every message is slow.
                // Ideally m_sessionKeys should hold the DECRYPTED keys in memory for the session duration.
                // Let's change semantic: m_sessionKeys holds PLAIN session keys.

                // In connectToServer/handleKeyUpdate, we decrypt the key before putting into m_sessionKeys.
                plain = ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
            } else {
                plain = "[Encrypted Message - Missing Key]";
            }

            QString text = QString::fromUtf8(plain);
            QString processedText = processMessageText(text);
            
            // Detect if it's a text file
            bool isTextFile = processedText.startsWith("📄FILE:");
            QString fileExtension;
            if (isTextFile) {
                // Extract extension from format: 📄FILE:ext:filename
                int firstColon = processedText.indexOf(':', 7); // After "📄FILE:"
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
    qDebug() << "handleNewMessage:";
    QString senderId = payload["sender_id"].toString();
    QString senderNickname = payload["sender_nickname"].toString();
    QByteArray cipher = QByteArray::fromBase64(payload["payload"].toString().toUtf8());
    QByteArray nonce = QByteArray::fromBase64(payload["nonce"].toString().toUtf8());
    QString ts = payload["timestamp"].toString();

    m_db.saveMessage(m_sessionId, senderId, senderNickname, cipher, nonce, ts, payload["key_version"].toInt());

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
    QString processedText = processMessageText(text);
    
    // Detect if it's a text file
    bool isTextFile = processedText.startsWith("📄FILE:");
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
    m_messages.append(msg);
    emit messagesChanged();
}

void ChatClient::sendMessage(const QString &text) {
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    // Store pending message for retry logic
    m_pendingMessage = text;

    // Use current (latest) key
    if (!m_sessionKeys.contains(m_currentKeyVersion)) {
        qWarning() << "Current key version" << m_currentKeyVersion << "not found in keys map!";
        return;
    }

    qDebug() << "[ChatClient] Sending message with Key Version" << m_currentKeyVersion;
    QByteArray nonce = ChatCrypto::generateNonce();
    // Use the PLAIN key for encryption
    QByteArray cipher = ChatCrypto::encrypt(text.toUtf8(), m_sessionKeys[m_currentKeyVersion], nonce);

    QJsonObject send;
    send["type"] = "SEND_MSG";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    p["sender_id"] = m_playerId;
    p["sender_nickname"] = m_nickname;
    p["payload"] = QString(cipher.toBase64());
    p["nonce"] = QString(nonce.toBase64());
    p["key_v"] = m_currentKeyVersion;
    send["payload"] = p;
    sendWebSocketMessage(send);
}

void ChatClient::sendImage(const QString &filePath) {
    qDebug() << "[ChatClient] Sending image (compressing...):" << filePath;
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;

    QImage img(localPath);
    if (img.isNull()) {
        qWarning() << "Could not load image:" << localPath;
        return;
    }

    // Resize if too large (max 1200px)
    if (img.width() > 1200 || img.height() > 1200) {
        img = img.scaled(1200, 1200, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    // Compress to JPEG
    QByteArray compressedData;
    QBuffer buffer(&compressedData);
    buffer.open(QIODevice::WriteOnly);
    img.save(&buffer, "WEBP", 90); // 90% quality

    QString base64 = QString("data:image/WEBP;base64,%1").arg(QString(compressedData.toBase64()));

    // Use current (latest) key
    if (!m_sessionKeys.contains(m_currentKeyVersion)) return;

    // Delegate to sendMessage to leverage retry logic
    sendMessage(base64);

    qDebug() << "[ChatClient] Compressed image sent (Size:" << compressedData.size() / 1024 << "KB)";
}

void ChatClient::sendTextFile(const QString &filePath) {
    qDebug() << "[ChatClient] Sending text file:" << filePath;
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;

    QFileInfo fileInfo(localPath);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        qWarning() << "[ChatClient] File not found:" << localPath;
        return;
    }

    // Limit file size to 1MB
    if (fileInfo.size() > 1024 * 1024) {
        qWarning() << "[ChatClient] File too large:" << fileInfo.size() << "bytes (max 1MB)";
        emit errorOccurred("Fichier trop volumineux (max 1MB)");
        return;
    }

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        qWarning() << "[ChatClient] Cannot open file:" << localPath;
        return;
    }

    QString content = QString::fromUtf8(file.readAll());
    file.close();

    QString extension = fileInfo.suffix().toLower();
    QString fileName = fileInfo.fileName();

    // Format: 📄FILE:ext:filename\n\ncontenu
    QString formattedMessage = QString::fromUtf8("\xF0\x9F\x93\x84") + "FILE:" + extension + ":" + fileName + "\n\n" + content;

    // Encrypt and send using sendMessage
    sendMessage(formattedMessage);
    qDebug() << "[ChatClient] Text file sent:" << fileName << "(" << extension << "," << content.size() << "chars)";
}

void ChatClient::saveTextToFile(const QString &filePath, const QString &content) {
    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;

    QFile file(localPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write(content.toUtf8());
        file.close();
        qDebug() << "[ChatClient] File saved to:" << localPath;
    } else {
        qWarning() << "[ChatClient] Failed to save file:" << localPath;
        emit errorOccurred("Impossible de sauvegarder le fichier");
    }
}

void ChatClient::clearHistory() {
    if (!m_connected) return;

    QJsonObject clear;
    clear["type"] = "CLEAR_HISTORY";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    clear["payload"] = p;

    sendWebSocketMessage(clear);
    qDebug() << "[ChatClient] Requesting history clear";
}

void ChatClient::loadHistory() {
    qDebug() << "[ChatClient] Loading history for session" << m_sessionId;
    m_messages.clear();
    QVariantList history = m_db.getMessages(m_sessionId);
    for (const QVariant &v : history) {
        QVariantMap m = v.toMap();
        QByteArray cipher = m["payload"].toByteArray();
        QByteArray nonce = m["nonce"].toByteArray();

        // Check for key_version (assuming it was saved, or default 1 if not)
        // Hmm, saveMessage didn't take key_version before.
        // We need to update ChatDatabase::saveMessage signature? Or just assume we can't save it yet?
        // Wait, m_db.getMessages returns QVariantMap.
        // If the DB schema doesn't have key_version yet, we have a problem.
        // But we added session_keys table. Did we update messages table?
        // We did not update ChatDatabase::saveMessage signature in the .h or .cpp in recent steps!
        // We only saw 'local_history' table creation.

        // For now, let's assume we try to decrypt with current key or try all keys?
        // No, that's inefficient.
        // Let's assume standard behavior: if version missing, try version 1.
        int keyVersion = 1;
        if (m.contains("key_version")) keyVersion = m["key_version"].toInt();

        QByteArray plain;
        if (m_sessionKeys.contains(keyVersion)) {
            plain = ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
        } else {
             plain = "[Encrypted (V" + QByteArray::number(keyVersion) + ")]";
        }

        QString text = QString::fromUtf8(plain);
        QString processedText = processMessageText(text);
        
        // Detect if it's a text file
        bool isTextFile = processedText.startsWith("📄FILE:");
        QString fileExtension;
        if (isTextFile) {
            int firstColon = processedText.indexOf(':', 7);
            if (firstColon > 7) {
                fileExtension = processedText.mid(7, firstColon - 7);
            }
        }

        QVariantMap msg;
        msg["sender"] = m["sender_id"];
        msg["senderNickname"] = m["sender_nickname"];
        msg["text"] = processedText;
        msg["isImage"] = processedText.startsWith("image://");
        msg["isTextFile"] = isTextFile;
        msg["fileExtension"] = fileExtension;
        msg["timestamp"] = m["timestamp"];
        m_messages.append(msg);
    }
    emit messagesChanged();
}

void ChatClient::requestHistory(int beforeId) {
    if (!m_connected) {
        qWarning() << "[ChatClient] Cannot request history: not connected to server";
        return;
    }

    qDebug() << "[ChatClient] Requesting history from server (beforeId:" << beforeId << ")";

    QJsonObject request;
    request["type"] = "GET_HISTORY";
    QJsonObject payload;
    payload["session_id"] = m_sessionId;
    if (beforeId > 0) {
        payload["before_id"] = beforeId;
    }
    request["payload"] = payload;

    sendWebSocketMessage(request);
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
        QString processedText = processMessageText(text);
        
        // Detect if it's a text file
        bool isTextFile = processedText.startsWith("📄FILE:");
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


void ChatClient::loadAndDecryptSessionKeys() {
    if (m_lockKey.isEmpty()) return;
    QMap<int, QByteArray> encryptedKeys = m_db.getSessionKeys(m_sessionId);
    for (auto it = encryptedKeys.begin(); it != encryptedKeys.end(); ++it) {
        int version = it.key();
        QByteArray combined = it.value();
        QDataStream stream(combined);
        QByteArray encryptedPkg, nonce;
        stream >> encryptedPkg >> nonce;
        QByteArray plainKey = ChatCrypto::decrypt(encryptedPkg, m_lockKey, nonce);
        if (!plainKey.isEmpty()) {
            m_sessionKeys.insert(version, plainKey);
            if (version > m_currentKeyVersion) {
                m_currentKeyVersion = version;
            }
        }
    }
}

QString ChatClient::processMessageText(const QString &text) {
    // Process images
    if (text.startsWith("data:image/")) {
        int commaIndex = text.indexOf(',');
        if (commaIndex != -1) {
            QString base64Data = text.mid(commaIndex + 1);
            QByteArray data = QByteArray::fromBase64(base64Data.toUtf8());
            QImage img = QImage::fromData(data);
            if (!img.isNull()) {
                QString id = ChatImageProvider::addImage(img);
                return QString("image://chat_images/%1").arg(id);
            }
        }
    }
    
    // Process text files (format: 📄FILE:ext:filename\n\ncontenu)
    if (text.startsWith("📄FILE:")) {
        // Return as-is, will be handled by QML
        return text;
    }
    
    return text;
}

void ChatClient::saveImageToFile(const QString &imageId, const QString &filePath) {
    QImage img = ChatImageProvider::getImage(imageId);
    if (img.isNull()) {
        qWarning() << "[ChatClient] Image not found for ID:" << imageId;
        emit errorOccurred("Image introuvable");
        return;
    }

    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;

    if (img.save(localPath)) {
        qDebug() << "[ChatClient] Image saved to:" << localPath;
    } else {
        qWarning() << "[ChatClient] Failed to save image to:" << localPath;
        emit errorOccurred("Impossible de sauvegarder l'image");
    }
}

void ChatClient::copyImageToClipboard(const QString &imageId) {
    QImage img = ChatImageProvider::getImage(imageId);
    if (img.isNull()) {
        qWarning() << "[ChatClient] Image not found for ID:" << imageId;
        return;
    }

    QClipboard *clipboard = QGuiApplication::clipboard();
    clipboard->setImage(img);
    qDebug() << "[ChatClient] Image copied to clipboard";
}
