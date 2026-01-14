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
        m_lockKey = ChatCrypto::deriveLockKey(id);
        emit sessionIdChanged();
    }
}

void ChatClient::connectToServer(const QString &url, const QString &playerId) {
    qDebug() << "[ChatClient] Connecting to server:" << url;
    m_playerId = playerId;
    
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
    }
}

void ChatClient::handleInitSession(const QJsonObject &payload) {
    qDebug() << "[ChatClient] Received init session:";
    QString keyPkgBase64 = payload["key_package"].toString();
    QString nonceBase64 = payload["nonce"].toString();

    if (!keyPkgBase64.isEmpty()) {
        QByteArray keyPkg = QByteArray::fromBase64(keyPkgBase64.toUtf8());
        QByteArray nonce = QByteArray::fromBase64(nonceBase64.toUtf8());
        m_sessionKey = ChatCrypto::decrypt(keyPkg, m_lockKey, nonce);
    } else {
        // Generate new session key if first arrival
        m_sessionKey = QByteArray(32, 0); // Placeholder 256-bit key
        // ... fill with random ...
        
        QByteArray nonce = ChatCrypto::generateNonce();
        QByteArray encryptedPkg = ChatCrypto::encrypt(m_sessionKey, m_lockKey, nonce);
        
        QJsonObject publish;
        publish["type"] = "PUBLISH_KEY";
        QJsonObject p;
        p["session_id"] = m_sessionId;
        p["blob"] = QString(encryptedPkg.toBase64());
        p["nonce"] = QString(nonce.toBase64());
        publish["payload"] = p;
        sendWebSocketMessage(publish);
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
            m_db.saveMessage(m_sessionId, senderId, cipher, nonce, ts);
            
            // Decrypt for UI
            QByteArray plain = ChatCrypto::decrypt(cipher, m_sessionKey, nonce);
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
    m_db.saveMessage(m_sessionId, senderId, cipher, nonce, ts);

    // Decrypt for UI
    QByteArray plain = ChatCrypto::decrypt(cipher, m_sessionKey, nonce);
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
    if (!m_connected || m_sessionKey.isEmpty()) return;
    qDebug() << "[ChatClient] Sending message:";
    QByteArray nonce = ChatCrypto::generateNonce();
    QByteArray cipher = ChatCrypto::encrypt(text.toUtf8(), m_sessionKey, nonce);

    QJsonObject send;
    send["type"] = "SEND_MSG";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    p["sender_id"] = m_playerId;
    p["payload"] = QString(cipher.toBase64());
    p["nonce"] = QString(nonce.toBase64());
    send["payload"] = p;

    sendWebSocketMessage(send);
    qDebug() << "[ChatClient] Message sent";
}

void ChatClient::sendImage(const QString &filePath) {
    qDebug() << "[ChatClient] Sending image (compressing...):" << filePath;
    if (!m_connected || m_sessionKey.isEmpty()) return;

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
    
    QByteArray nonce = ChatCrypto::generateNonce();
    QByteArray cipher = ChatCrypto::encrypt(base64.toUtf8(), m_sessionKey, nonce);

    QJsonObject send;
    send["type"] = "SEND_MSG";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    p["sender_id"] = m_playerId;
    p["payload"] = QString(cipher.toBase64());
    p["nonce"] = QString(nonce.toBase64());
    send["payload"] = p;

    sendWebSocketMessage(send);
    qDebug() << "[ChatClient] Compressed image sent (Size:" << compressedData.size() / 1024 << "KB)";
}

void ChatClient::loadHistory() {
    qDebug() << "[ChatClient] Loading history for session" << m_sessionId;
    m_messages.clear();
    QVariantList history = m_db.getMessages(m_sessionId);
    for (const QVariant &v : history) {
        QVariantMap m = v.toMap();
        QByteArray cipher = m["payload"].toByteArray();
        QByteArray nonce = m["nonce"].toByteArray();
        
        QByteArray plain = ChatCrypto::decrypt(cipher, m_sessionKey, nonce);
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
        m_db.saveMessage(m_sessionId, senderId, cipher, nonce, ts);
        
        // Decrypt for UI
        QByteArray plain = ChatCrypto::decrypt(cipher, m_sessionKey, nonce);
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
