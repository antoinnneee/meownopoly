#include "chat_client.h"
#include <QJsonDocument>
#include <QDebug>

ChatClient::ChatClient(QObject *parent) : QObject(parent) {
    connect(&m_webSocket, &QWebSocket::connected, this, &ChatClient::onConnected);
    connect(&m_webSocket, &QWebSocket::disconnected, this, &ChatClient::onDisconnected);
    connect(&m_webSocket, &QWebSocket::textMessageReceived, this, &ChatClient::onTextMessageReceived);
    
    m_db.init();
}

void ChatClient::setSessionId(const QString &id) {
    if (m_sessionId != id) {
        m_sessionId = id;
        m_lockKey = ChatCrypto::deriveLockKey(id);
        emit sessionIdChanged();
    }
}

void ChatClient::connectToServer(const QString &url, const QString &playerId) {
    qDebug() << "Connecting to server:" << url;
    m_playerId = playerId;
    m_webSocket.open(QUrl(url));
}

void ChatClient::onConnected() {
    qDebug() << "Connected to server";
    m_connected = true;
    emit connectedChanged();

    // Join session
    QJsonObject join;
    join["type"] = "JOIN_SESSION";
    QJsonObject payload;
    payload["session_id"] = m_sessionId;
    payload["player_id"] = m_playerId;
    join["payload"] = payload;

    m_webSocket.sendTextMessage(QJsonDocument(join).toJson(QJsonDocument::Compact));
}

void ChatClient::onDisconnected() {
    qDebug() << "Disconnected from server";
    m_connected = false;
    emit connectedChanged();
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
    }
}

void ChatClient::handleInitSession(const QJsonObject &payload) {
    qDebug() << "Received init session:";
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
        m_webSocket.sendTextMessage(QJsonDocument(publish).toJson(QJsonDocument::Compact));
    }

    // Load local history
    loadHistory();
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
    
    QVariantMap msg;
    msg["sender"] = senderId;
    msg["text"] = text;
    msg["isImage"] = text.startsWith("data:image/");
    msg["timestamp"] = ts;
    m_messages.append(msg);
    emit messagesChanged();
}

void ChatClient::sendMessage(const QString &text) {
    if (!m_connected || m_sessionKey.isEmpty()) return;
    qDebug() << "Sending message:";
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

    m_webSocket.sendTextMessage(QJsonDocument(send).toJson(QJsonDocument::Compact));
    qDebug() << "Message sent:" << QJsonDocument(send).toJson(QJsonDocument::Compact);
}

void ChatClient::sendImage(const QString &filePath) {
    qDebug() << "Sending image:" << filePath;
    if (!m_connected || m_sessionKey.isEmpty()) return;

    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;
    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning() << "Could not open image file:" << localPath;
        return;
    }

    QByteArray data = file.readAll();
    QFileInfo fileInfo(localPath);
    QString ext = fileInfo.suffix().toLower();
    QString mimeType = "image/png"; // Default
    if (ext == "jpg" || ext == "jpeg") mimeType = "image/jpeg";
    else if (ext == "gif") mimeType = "image/gif";
    else if (ext == "webp") mimeType = "image/webp";

    QString base64 = QString("data:%1;base64,%2").arg(mimeType).arg(QString(data.toBase64()));
    
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

    m_webSocket.sendTextMessage(QJsonDocument(send).toJson(QJsonDocument::Compact));
}

void ChatClient::loadHistory() {
    qDebug() << "Loading history for session" << m_sessionId;
    m_messages.clear();
    QVariantList history = m_db.getMessages(m_sessionId);
    for (const QVariant &v : history) {
        QVariantMap m = v.toMap();
        QByteArray cipher = m["payload"].toByteArray();
        QByteArray nonce = m["nonce"].toByteArray();
        
        QByteArray plain = ChatCrypto::decrypt(cipher, m_sessionKey, nonce);
        QString text = QString::fromUtf8(plain);
        
        QVariantMap msg;
        msg["sender"] = m["sender_id"];
        msg["text"] = text;
        msg["isImage"] = text.startsWith("data:image/");
        msg["timestamp"] = m["timestamp"];
        m_messages.append(msg);
    }
    emit messagesChanged();
}
