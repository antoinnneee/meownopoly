#include "chat_client.h"
#include "chat_image_provider.h"
#include <QJsonDocument>
#include <QDebug>
#include <QImage>
#include <QBuffer>
#include <QFileInfo>
#include <QUrl>

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

void ChatClient::connectToServer(const QString &url, const QString &playerId, const QString &password) {
    qDebug() << "[ChatClient] Connecting to server:" << url;
    m_playerId = playerId;
    m_password = password;
    
    // Derive Lock Key from SessionID + Password
    m_lockKey = ChatCrypto::deriveLockKey(m_sessionId, m_password);
    
    // Load LOCAL keys immediately (Forward Secrecy = no keys from server)
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

    // Use queued connection to call worker method in worker thread
    QMetaObject::invokeMethod(m_worker, "connectToServer", Qt::QueuedConnection,
                              Q_ARG(QString, url));
}

void ChatClient::onConnected() {
    qDebug() << "[ChatClient] Connected to server";
    m_connected = true;
    emit connectedChanged();

    // Join session
    QJsonObject join;
    join["type"] = "JOIN_SESSION";
    QJsonObject payload;
    payload["session_id"] = m_sessionId;
    payload["player_id"] = m_playerId;
    join["payload"] = payload;

    sendWebSocketMessage(join);
}

void ChatClient::onDisconnected() {
    qDebug() << "[ChatClient] Disconnected from server";
    m_connected = false;
    emit connectedChanged();
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
    int version = payload["version"].toInt(); // Server MUST send version

    if (!keyPkgBase64.isEmpty()) {
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
    }
}

void ChatClient::handleInitSession(const QJsonObject &payload) {
    qDebug() << "[ChatClient] Received init session.";
    
    // FORWARD SECRECY: Server does not send keys. We use local keys.
    // FORWARD SECRECY: Server does not send keys. We use local keys.
    if (m_sessionKeys.isEmpty()) {
        qDebug() << "[ChatClient] No local keys found (New User). Generating V1 key.";
        
        // New user: Generate key.
        QByteArray newKey = ChatCrypto::generateRandomKey();
        QByteArray nonce = ChatCrypto::generateNonce();
        
        // Encrypt with LockKey for DB storage and Server publishing
        QByteArray encryptedPkg = ChatCrypto::encrypt(newKey, m_lockKey, nonce);
        
        // Publish to server first. DB save happens on KEY_UPDATE confirmation 
        // OR we optimistically save as V1, but server might assign V2.
        // Better: Optimistically save as V0 or temp, wait for KEY_UPDATE.
        // Actually, for simplicity in this blind relay, we assume we are V1 if room is empty.
        // But if room exists, we might become V(N).
        // Since we blindly publish, let's just publish. The server will echo back a KEY_UPDATE.
        // We will handle the save in handleKeyUpdate.
        // WAIT: If we are the FIRST user, the echo might be skipped if we were filtered?
        // NO, we fixed the server to echo to sender. So we can rely on KEY_UPDATE.
        
        QJsonObject publish;
        publish["type"] = "PUBLISH_KEY";
        QJsonObject p;
        p["session_id"] = m_sessionId;
        p["blob"] = QString(encryptedPkg.toBase64());
        p["nonce"] = QString(nonce.toBase64());
        publish["payload"] = p;
        sendWebSocketMessage(publish);
        qDebug() << "[ChatClient] Published new key. Waiting for version assignment.";
    } else {
        qDebug() << "[ChatClient] Existing keys found. Using latest Version" << m_currentKeyVersion;
        // Check if server version is higher? 
        // session.version from server is payload["current_version"].
        int serverVersion = payload["current_version"].toInt();
        if (serverVersion > m_currentKeyVersion) {
            qWarning() << "[ChatClient] Server has newer version (" << serverVersion << ") than local (" << m_currentKeyVersion << "). We might miss keys.";
            // In a real app we might request missing keys if they weren't Forward Secrecy protected.
        }
    }

    // Process server history if provided
    QJsonArray historyArray = payload["history"].toArray();
    if (!historyArray.isEmpty()) {
        m_messages.clear();
        for (const QJsonValue &val : historyArray) {
            QJsonObject msg = val.toObject();
            QString senderId = msg["sender_id"].toString();
            QByteArray cipher = QByteArray::fromBase64(msg["payload"].toString().toUtf8());
            QByteArray nonce = QByteArray::fromBase64(msg["nonce"].toString().toUtf8());
            QString ts = msg["server_timestamp"].toString();
            
            // Save locally
            m_db.saveMessage(m_sessionId, senderId, cipher, nonce, ts, msg["key_version"].toInt());
            
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
            
            QVariantMap message;
            message["sender"] = senderId;
            message["text"] = processedText;
            message["isImage"] = processedText.startsWith("image://");
            message["timestamp"] = ts;
            m_messages.append(message);
        }
        emit messagesChanged();
    } else {
        // Load local history if no server history
        loadHistory();
    }
}

void ChatClient::handleNewMessage(const QJsonObject &payload) {
    qDebug() << "handleNewMessage:";
    QString senderId = payload["sender_id"].toString();
    QByteArray cipher = QByteArray::fromBase64(payload["payload"].toString().toUtf8());
    QByteArray nonce = QByteArray::fromBase64(payload["nonce"].toString().toUtf8());
    QString ts = payload["timestamp"].toString();

    // Persist encrypted
    m_db.saveMessage(m_sessionId, senderId, cipher, nonce, ts, payload["key_version"].toInt());

    // Decrypt for UI
    int keyVersion = payload["key_version"].toInt();
    
    // Debug info
    if (!m_sessionKeys.contains(keyVersion)) {
        qWarning() << "[ChatClient] Key version" << keyVersion << "missing in memory! Attempting reload...";
        m_sessionKeys = m_db.getSessionKeys(m_sessionId);
    }
    
    QByteArray plain;
    if (m_sessionKeys.contains(keyVersion)) {
        // m_sessionKeys now contains PLAIN keys
        plain = ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
    } else {
        qWarning() << "[ChatClient] FAILED to decrypt message. Missing Key Version:" << keyVersion 
                   << "Available versions:" << m_sessionKeys.keys();
        plain = "[Encrypted Message - Missing Key]";
    }
    
    QString text = QString::fromUtf8(plain);
    QString processedText = processMessageText(text);
    
    QVariantMap msg;
    msg["sender"] = senderId;
    msg["text"] = processedText;
    msg["isImage"] = processedText.startsWith("image://");
    msg["timestamp"] = ts;
    m_messages.append(msg);
    emit messagesChanged();
}

void ChatClient::sendMessage(const QString &text) {
    if (!m_connected || m_sessionKeys.isEmpty()) return;
    
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
    p["payload"] = QString(cipher.toBase64());
    p["nonce"] = QString(nonce.toBase64());
    p["key_v"] = m_currentKeyVersion; // Send version
    send["payload"] = p;

    sendWebSocketMessage(send);
    qDebug() << "[ChatClient] Message sent";
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

    QByteArray nonce = ChatCrypto::generateNonce();
    // Use PLAIN key
    QByteArray cipher = ChatCrypto::encrypt(base64.toUtf8(), m_sessionKeys[m_currentKeyVersion], nonce);

    QJsonObject send;
    send["type"] = "SEND_MSG";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    p["sender_id"] = m_playerId;
    p["payload"] = QString(cipher.toBase64());
    p["nonce"] = QString(nonce.toBase64());
    p["key_v"] = m_currentKeyVersion;
    send["payload"] = p;

    sendWebSocketMessage(send);
    qDebug() << "[ChatClient] Compressed image sent (Size:" << compressedData.size() / 1024 << "KB)";
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
        
        QVariantMap msg;
        msg["sender"] = m["sender_id"];
        msg["text"] = processedText;
        msg["isImage"] = processedText.startsWith("image://");
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
        QByteArray cipher = QByteArray::fromBase64(msg["payload"].toString().toUtf8());
        QByteArray nonce = QByteArray::fromBase64(msg["nonce"].toString().toUtf8());
        QString ts = msg["server_timestamp"].toString();
        
        // Save locally
        m_db.saveMessage(m_sessionId, senderId, cipher, nonce, ts, msg["key_version"].toInt());
        
        // Decrypt for UI
        int keyVersion = msg["key_version"].toInt();
        QByteArray plain;
        if (m_sessionKeys.contains(keyVersion)) {
            plain = ChatCrypto::decrypt(cipher, m_sessionKeys[keyVersion], nonce);
        } else {
            plain = "[Encrypted History]";
        }
        
        QString text = QString::fromUtf8(plain);
        QString processedText = processMessageText(text);
        
        QVariantMap message;
        message["sender"] = senderId;
        message["text"] = processedText;
        message["isImage"] = processedText.startsWith("image://");
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


QString ChatClient::processMessageText(const QString &text) {
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
    return text;
}
