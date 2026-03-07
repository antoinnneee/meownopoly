#include "chat_client.h"
#include "chat_image_provider.h"
#include "../account/account_manager.h"

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
    connect(m_worker, &ChatWorker::errorOccurred, this, &ChatClient::onWorkerError);

    // Connect client signals to worker slots (cross-thread)
    connect(this, &ChatClient::destroyed, m_worker, &ChatWorker::deleteLater);

    // Start the worker thread
    m_workerThread->start();

    Logger::instance()->info("Initialized with worker thread", "ChatClient");
}

ChatClient::~ChatClient() {
    Logger::instance()->debug("Destructor called", "ChatClient");

    // Stop the worker thread
    if (m_workerThread) {
        m_workerThread->quit();
        if (!m_workerThread->wait(3000)) {
            Logger::instance()->warn("Worker thread did not finish in time, terminating", "ChatClient");
            m_workerThread->terminate();
            m_workerThread->wait();
        }
    }

    Logger::instance()->debug("Destroyed", "ChatClient");
}

void ChatClient::setSessionId(const QString &id) {
    if (m_sessionId != id) {
        m_sessionId = id;
        // Lock key now requires password, defer derivation
        emit sessionIdChanged();
    }
}

void ChatClient::connectToServer(const QString &url) {
    Logger::instance()->info(QString("Connecting to server: %1").arg(url), "ChatClient");
    
    // Reset session data on new connection attempt? 
    // For now, we just connect. Session data is handled by connectToSession.

    // Use queued connection to call worker method in worker thread
    QMetaObject::invokeMethod(m_worker, "connectToServer", Qt::QueuedConnection,
                              Q_ARG(QString, url));
}

void ChatClient::createSession(QString nameSession, QString pwdSession, QString idSession) {
    m_playerId  = AccountManager::instance()->uniqueId();
    m_nickname  = AccountManager::instance()->nickname();
    m_sessionId = idSession;
    m_password  = pwdSession;

    m_lockKey     = ChatCrypto::deriveLockKey(m_sessionId, m_password);
    m_passwordHash = ChatCrypto::derivePasswordProof(m_sessionId, m_password);

    if (!m_connected) {
        emit errorOccurred("Non connect� au serveur");
        return;
    }

    QJsonObject msg;
    msg["type"] = "CREATE_SESSION";
    QJsonObject payload;
    payload["session_id"]    = m_sessionId;
    payload["session_name"]  = nameSession;
    payload["password_hash"] = QString(m_passwordHash.toBase64());
    payload["max_players"]   = 4;
    payload["is_public"]     = true;
    msg["payload"] = payload;

    sendWebSocketMessage(msg);
    Logger::instance()->info(
        QString("Requesting session creation: %1 (%2)").arg(idSession).arg(nameSession),
        "ChatClient");
}

void ChatClient::connectToSessionDirect(const QString &sessionId, const QString &password)
{

    m_playerId = AccountManager::instance()->uniqueId();
    m_nickname = AccountManager::instance()->nickname();
    m_sessionId = sessionId;
    m_password = password;

    joinSession();
}

void ChatClient::connectToSession(const QString &playerId, const QString &password, const QString &nickname) {

    m_playerId = playerId;
    m_nickname = nickname.isEmpty() ? playerId : nickname;
    m_password = password;

    joinSession();
}

void ChatClient::joinSession(){

    if (m_sessionId.isEmpty()) {Logger::instance()->warn("Session ID cannot be empty", "ChatClient");emit errorOccurred("L'ID de session ne peut pas �tre vide");return;}
    if (m_playerId.isEmpty()) {Logger::instance()->warn("Player ID cannot be empty", "ChatClient");emit errorOccurred("L'ID de joueur ne peut pas �tre vide");return;}

    Logger::instance()->info(QString("Preparing session %4 for player: %2_%1, %3").arg(m_playerId).arg(m_nickname).arg(m_password).arg(m_sessionId), "ChatClient");

    // Derive Lock Key from SessionID + Password
    m_lockKey = ChatCrypto::deriveLockKey(m_sessionId, m_password);
    m_passwordHash = ChatCrypto::derivePasswordProof(m_sessionId, m_password);

    // Load LOCAL keys immediately (Forward Secrecy = no keys from server)
    // Keys in DB are encrypted with lockKey. We must decrypt them for memory usage.
    m_sessionKeys.clear();
    loadAndDecryptSessionKeys();

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
        payload["session_id"]     = m_sessionId;
        payload["player_id"]      = m_playerId;
        payload["player_nickname"] = m_nickname;
        payload["password_hash"]  = QString(m_passwordHash.toBase64());
        join["payload"] = payload;

        sendWebSocketMessage(join);

        // Request participants list right after joining
        requestParticipants();
    }
}


void ChatClient::onConnected() {
    Logger::instance()->info("Connected to server", "ChatClient");
    m_connected = true;
    emit connectedChanged();
}

void ChatClient::onDisconnected() {
    Logger::instance()->info("Disconnected from server", "ChatClient");
    m_connected = false;
    m_participants.clear();
    m_pendingMessage.clear();
    m_retryPending = false;
    emit connectedChanged();
    emit participantsChanged();
}

void ChatClient::onWorkerError(const QString &error) {
    emit errorOccurred(error, ChatClient::OTHER);
}

void ChatClient::sendWebSocketMessage(const QJsonObject &message) {
    QString jsonString = QJsonDocument(message).toJson(QJsonDocument::Compact);
    QMetaObject::invokeMethod(m_worker, "sendTextMessage", Qt::QueuedConnection,
                              Q_ARG(QString, jsonString));
}

void ChatClient::requestParticipants() {
    if (!m_connected) {
        Logger::instance()->warn("Cannot request participants: not connected", "ChatClient");
        return;
    }

    QJsonObject request;
    request["type"] = "GET_PARTICIPANTS";
    QJsonObject payload;
    payload["session_id"] = m_sessionId;
    request["payload"] = payload;

    sendWebSocketMessage(request);
    Logger::instance()->debug(QString("Requested participants list for session %1").arg(m_sessionId), "ChatClient");
}

void ChatClient::requestSessionsList() {
    if (!m_connected) {
        Logger::instance()->warn("Cannot request sessions list: not connected", "ChatClient");
        return;
    }

    Logger::instance()->debug("Requesting sessions list", "ChatClient");
    
    QJsonObject msg;
    msg["type"] = "LIST_SESSIONS";
    msg["payload"] = QJsonObject();

    sendWebSocketMessage(msg);
}

void ChatClient::kickPlayer(const QString &targetPlayerId) {
    if (!m_connected || m_sessionId.isEmpty()) return;

    Logger::instance()->info(QString("Kicking player %1 from session %2").arg(targetPlayerId).arg(m_sessionId), "ChatClient");

    QJsonObject kick;
    kick["type"] = "KICK";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    p["target_player_id"] = targetPlayerId;
    kick["payload"] = p;

    sendWebSocketMessage(kick);
    // Demander la liste � jour apr�s exclusion d'un participant
    requestParticipants();
}


void ChatClient::publishNewKey() {
    if (m_lockKey.isEmpty()) {
        Logger::instance()->warn("Cannot publish key: LockKey not derived (missing password?)", "ChatClient");
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
    Logger::instance()->info("Published new key. Waiting for KEY_UPDATE.", "ChatClient");
}


void ChatClient::clearHistory() {
    if (!m_connected) return;

    QJsonObject clear;
    clear["type"] = "CLEAR_HISTORY";
    QJsonObject p;
    p["session_id"] = m_sessionId;
    clear["payload"] = p;

    sendWebSocketMessage(clear);
    Logger::instance()->debug("Requesting history clear", "ChatClient");
}

void ChatClient::loadHistory() {
    Logger::instance()->debug(QString("Loading history for session %1").arg(m_sessionId), "ChatClient");
    m_messages.clear();
    QVariantList history = m_db.getMessages(m_sessionId);
    for (const QVariant &v : history) {
        QVariantMap m = v.toMap();
        QByteArray cipher = m["payload"].toByteArray();
        QByteArray nonce = m["nonce"].toByteArray();

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
        bool isTextFile = processedText.startsWith(QString::fromUtf8("\xF0\x9F\x93\x84") + "FILE:");
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
        Logger::instance()->warn("Cannot request history: not connected to server", "ChatClient");
        return;
    }

    Logger::instance()->debug(QString("Requesting history from server (beforeId: %1)").arg(beforeId), "ChatClient");

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
        } else {
            Logger::instance()->warn(QString("Failed to decrypt session key Version %1").arg(version), "ChatClient");
        }
    }
    Logger::instance()->info(QString("Loaded %1 session keys into memory").arg(m_sessionKeys.size()), "ChatClient");
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
    
    // Process text files (format: ??FILE:ext:filename\n\ncontenu)
    if (text.startsWith(QString::fromUtf8("\xF0\x9F\x93\x84") + "FILE:")) {
        // Return as-is, will be handled by QML
        return text;
    }

    return text;
}

void ChatClient::saveImageToFile(const QString &imageId, const QString &filePath) {
    QImage img = ChatImageProvider::getImage(imageId);
    if (img.isNull()) {
        Logger::instance()->warn(QString("Image not found for ID: %1").arg(imageId), "ChatClient");
        emit errorOccurred("Image introuvable");
        return;
    }

    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;

    if (img.save(localPath)) {
        Logger::instance()->debug(QString("Image saved to: %1").arg(localPath), "ChatClient");
    } else {
        Logger::instance()->warn(QString("Failed to save image to: %1").arg(localPath), "ChatClient");
        emit errorOccurred("Impossible de sauvegarder l'image");
    }
}

void ChatClient::copyImageToClipboard(const QString &imageId) {
    QImage img = ChatImageProvider::getImage(imageId);
    if (img.isNull()) {
        Logger::instance()->warn(QString("Image not found for ID: %1").arg(imageId), "ChatClient");
        return;
    }

    QClipboard *clipboard = QGuiApplication::clipboard();
    clipboard->setImage(img);
    Logger::instance()->debug("Image copied to clipboard", "ChatClient");
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
            Logger::instance()->warn("Failed to decode image in background thread", "ChatClient");
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
