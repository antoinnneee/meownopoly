#include "chat_client.h"
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
        dispatchIncomingCommand(senderId, commandType, data);
        emit commandReceived(senderId, commandType, data);
    }
}

void ChatClient::dispatchIncomingCommand(const QString &senderId, const QString &commandType, const QJsonObject &data) {
    if (commandType == "PING")
        onIncomingCommandPing(senderId, data);
    else if (commandType == "PONG")
        onIncomingCommandPong(senderId, data);
    /*
        REQUEST_CONNECTION_INFO & REPLY_CONNECTION_INFO are handled by Catway.cpp
    */
}

void ChatClient::onIncomingCommandPing(const QString &senderId, const QJsonObject &data) {
    Logger::instance()->debug(QString("Auto-responding with PONG to %1").arg(senderId), "ChatClient");
    sendCommand("PONG", data, senderId);
}

void ChatClient::onIncomingCommandPong(const QString &senderId, const QJsonObject &data) {
    qint64 sentTs = data["timestamp"].toVariant().toLongLong();
    qint64 now = QDateTime::currentMSecsSinceEpoch();
    Logger::instance()->debug(QString("Received PONG from %1 Roundtrip: %2 ms").arg(senderId).arg(now - sentTs), "ChatClient");
}

void ChatClient::sendCommand(const QString &commandType, const QJsonObject &data, const QString &recipientId) {
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    if (!m_sessionKeys.contains(m_currentKeyVersion)) {
        Logger::instance()->warn(QString("Current key version %1 not found for sendCommand!").arg(m_currentKeyVersion), "ChatClient");
        return;
    }

    Logger::instance()->debug(QString("Sending command %1 to %2").arg(commandType).arg(recipientId.isEmpty() ? "all" : recipientId), "ChatClient");

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
    Logger::instance()->debug(QString("Sending PING to %1").arg(targetPlayerId.isEmpty() ? "all" : targetPlayerId), "ChatClient");
    QJsonObject data;
    data["timestamp"] = QDateTime::currentMSecsSinceEpoch();
    sendCommand("PING", data, targetPlayerId);
}

void ChatClient::sendRequestConnectionInfo(const QString &recipientId, const QString &ip, quint16 port) {
    if (ip.isEmpty() || port == 0) {
        Logger::instance()->error(
            QString("sendRequestConnectionInfo annulé : socket manquant ou port invalide (ip='%1', port=%2)").arg(ip).arg(port),
            "ChatClient");
        return;
    }
    Logger::instance()->debug(QString("Sending REQUEST_CONNECTION_INFO to %1").arg(recipientId.isEmpty() ? "all" : recipientId), "ChatClient");
    QJsonObject data;
    data["ip"] = ip;
    data["port"] = static_cast<int>(port);
    sendCommand("REQUEST_CONNECTION_INFO", data, recipientId);
}


void ChatClient::sendShareConnection(const QString &recipientId) {
    Logger::instance()->debug(QString("Sending REPLY_CONNECTION_INFO to %1 (placeholder)").arg(recipientId.isEmpty() ? "all" : recipientId), "ChatClient");
    QJsonObject data;
    // Placeholder: à remplacer par l'IP et le port réels du serveur/hôte
    data["ip"] = QStringLiteral("0.0.0.0");
    data["port"] = 0;
    sendCommand("REPLY_CONNECTION_INFO", data, recipientId);
}
