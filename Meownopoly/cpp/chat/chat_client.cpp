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
    m_playerId = playerId;
    m_webSocket.open(QUrl(url));
}

void ChatClient::onConnected() {
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
    m_connected = false;
    emit connectedChanged();
}

void ChatClient::onTextMessageReceived(const QString &message) {
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
    QString senderId = payload["sender_id"].toString();
    QByteArray cipher = QByteArray::fromBase64(payload["payload"].toString().toUtf8());
    QByteArray nonce = QByteArray::fromBase64(payload["nonce"].toString().toUtf8());
    QString ts = payload["timestamp"].toString();

    // Persist encrypted
    m_db.saveMessage(m_sessionId, senderId, cipher, nonce, ts);

    // Decrypt for UI
    QByteArray plain = ChatCrypto::decrypt(cipher, m_sessionKey, nonce);
    
    QVariantMap msg;
    msg["sender"] = senderId;
    msg["text"] = QString::fromUtf8(plain);
    msg["timestamp"] = ts;
    m_messages.append(msg);
    emit messagesChanged();
}

void ChatClient::sendMessage(const QString &text) {
    if (!m_connected || m_sessionKey.isEmpty()) return;

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
}

void ChatClient::loadHistory() {
    m_messages.clear();
    QVariantList history = m_db.getMessages(m_sessionId);
    for (const QVariant &v : history) {
        QVariantMap m = v.toMap();
        QByteArray cipher = m["payload"].toByteArray();
        QByteArray nonce = m["nonce"].toByteArray();
        
        QByteArray plain = ChatCrypto::decrypt(cipher, m_sessionKey, nonce);
        
        QVariantMap msg;
        msg["sender"] = m["sender_id"];
        msg["text"] = QString::fromUtf8(plain);
        msg["timestamp"] = m["timestamp"];
        m_messages.append(msg);
    }
    emit messagesChanged();
}
