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
    m_passwordHash = ChatCrypto::derivePasswordProof(m_sessionId, m_password);

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

    if (!m_playerId.isEmpty() && !m_sessionId.isEmpty()) {

    // Join session
    QJsonObject join;
    join["type"] = "JOIN_SESSION";
    QJsonObject payload;
    payload["session_id"] = m_sessionId;
    payload["player_id"] = m_playerId;
    payload["player_nickname"] = m_nickname;
    payload["password_hash"] = QString(m_passwordHash);
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

void ChatClient::kickPlayer(const QString &targetPlayerId) {
    if (!m_connected || m_sessionId.isEmpty()) return;

    qDebug() << "[ChatClient] Kicking player" << targetPlayerId << "from session" << m_sessionId;

    QJsonObject kick;
    kick["type"] = "KICK";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    p["target_player_id"] = targetPlayerId;
    kick["payload"] = p;

    sendWebSocketMessage(kick);
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
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    // Use QtConcurrent to process the image in a background thread
    QtConcurrent::run([this, filePath]() {
        qDebug() << "[ChatClient] Sending image (compressing in background...):" << filePath;

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

        // Compress to WEBP
        QByteArray compressedData;
        QBuffer buffer(&compressedData);
        buffer.open(QIODevice::WriteOnly);
        img.save(&buffer, "WEBP", 90); // 90% quality

        QString base64 = QString("data:image/WEBP;base64,%1").arg(QString(compressedData.toBase64()));
        int sizeKb = compressedData.size() / 1024;

        // Return to main thread to send the message via WebSocket
        QMetaObject::invokeMethod(this, [this, base64, sizeKb]() {
            if (!m_connected || m_sessionKeys.isEmpty()) return;

            // Use current (latest) key
            if (!m_sessionKeys.contains(m_currentKeyVersion)) return;

            // Delegate to sendMessage to leverage retry logic
            sendMessage(base64);

            qDebug() << "[ChatClient] Compressed image sent (Size:" << sizeKb << "KB)";
        }, Qt::QueuedConnection);
    });
}

void ChatClient::sendCommand(const QString &commandType, const QJsonObject &data, const QString &recipientId) {
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    if (!m_sessionKeys.contains(m_currentKeyVersion)) {
        qWarning() << "[ChatClient] Current key version" << m_currentKeyVersion << "not found for sendCommand!";
        return;
    }

    qDebug() << "[ChatClient] Sending command" << commandType << "to" << (recipientId.isEmpty() ? "all" : recipientId);

    QString internalPayload = ChatCommandHelper::formatCommand(commandType, data);
    QByteArray nonce = ChatCrypto::generateNonce();
    QByteArray cipher = ChatCrypto::encrypt(internalPayload.toUtf8(), m_sessionKeys[m_currentKeyVersion], nonce);

    QJsonObject send;
    send["type"] = "SEND_COMMAND";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    if (!recipientId.isEmpty()) {
        p["recipient_id"] = recipientId;
    }
    p["payload"] = QString(cipher.toBase64());
    p["nonce"] = QString(nonce.toBase64());
    p["key_v"] = m_currentKeyVersion;
    send["payload"] = p;

    sendWebSocketMessage(send);
}

void ChatClient::sendPing(const QString &targetPlayerId) {
    qDebug() << "[ChatClient] Sending PING to" << (targetPlayerId.isEmpty() ? "all" : targetPlayerId);
    QJsonObject data;
    data["timestamp"] = QDateTime::currentMSecsSinceEpoch();
    sendCommand("PING", data, targetPlayerId);
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
    QString formattedMessage = /*QString::fromUtf8("\xF0\x9F\x93\x84") +*/ "FILE:" + extension + ":" + fileName + "\n\n" + content;

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
        if (text.startsWith("data:image/")) {
            QVariantMap placeholder;
            placeholder["sender"] = m["sender_id"];
            placeholder["senderNickname"] = m["sender_nickname"];
            placeholder["text"] = "Chargement de l'image...";
            placeholder["isImage"] = false; // Fix: Keep false
            placeholder["isTextFile"] = false;
            placeholder["timestamp"] = m["timestamp"];
            placeholder["isLoading"] = true;
            m_messages.append(placeholder);
            decodeImageAsync(m["sender_id"].toString(), text, m["timestamp"].toString());
            continue;
        }

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

void ChatClient::decodeImageAsync(const QString &senderId, const QString &text, const QString &ts) {
    // text is the full base64 string
    QtConcurrent::run([this, senderId, ts, text]() {
        int commaIndex = text.indexOf(',');
        if (commaIndex == -1) return;

        QString base64Data = text.mid(commaIndex + 1);
        QByteArray data = QByteArray::fromBase64(base64Data.toUtf8());
        QImage img = QImage::fromData(data);
        
        if (!img.isNull()) {
            QString imageId = ChatImageProvider::addImage(img);
            QString imageUri = QString("image://chat_images/%1").arg(imageId);

            // Return to main thread to update the message
            QMetaObject::invokeMethod(this, [this, senderId, ts, imageUri]() {
                for (int i = 0; i < m_messages.size(); ++i) {
                    QVariantMap m = m_messages[i].toMap();
                    if (m["sender"].toString() == senderId && m["timestamp"].toString() == ts && m.value("isLoading").toBool()) {
                        m["text"] = imageUri;
                        m["isImage"] = true; // Now it's an image
                        m["isLoading"] = false;
                        m_messages[i] = m;
                        emit messagesChanged(); 
                        break;
                    }
                }
            }, Qt::QueuedConnection);
        } else {
             qWarning() << "[ChatClient] Failed to decode image in background thread";
             QMetaObject::invokeMethod(this, [this, senderId, ts]() {
                for (int i = 0; i < m_messages.size(); ++i) {
                    QVariantMap m = m_messages[i].toMap();
                    if (m["sender"].toString() == senderId && m["timestamp"].toString() == ts && m.value("isLoading").toBool()) {
                        m["text"] = "[Erreur de chargement d'image]";
                        m["isLoading"] = false;
                        m_messages[i] = m;
                        emit messagesChanged();
                        break;
                    }
                }
            }, Qt::QueuedConnection);
        }
    });
}
