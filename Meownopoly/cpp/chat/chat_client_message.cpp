#include "chat_client.h"
#include "chat_crypto.h"
#include "tools/logger.h"
#include <QJsonObject>
#include <QDateTime>
#include <QUrl>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QBuffer>
#include <QtConcurrent>

void ChatClient::sendMessage(const QString &text, const QString &recipientId, const QString &recipientNickname) {
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    // Store pending message for retry logic (only for broadcast, not for private)
    if (recipientId.isEmpty())
        m_pendingMessage = text;

    // Use current (latest) key
    if (!m_sessionKeys.contains(m_currentKeyVersion)) {
        Logger::instance()->warn(QString("Current key version %1 not found in keys map!").arg(m_currentKeyVersion), "ChatClient");
        return;
    }

    Logger::instance()->debug(QString("Sending message with Key Version %1 %2").arg(m_currentKeyVersion).arg(recipientId.isEmpty() ? "(broadcast)" : QString("(to %1)").arg(recipientId)), "ChatClient");
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
    if (!recipientId.isEmpty())
        p["recipient_id"] = recipientId;
    send["payload"] = p;

    sendWebSocketMessage(send);

    // Affichage optimiste : afficher notre message tout de suite (nécessaire pour les messages privés que le serveur ne nous renvoie pas)
    const QString ts = QDateTime::currentDateTime().toString(Qt::ISODate);
    const bool isPrivate = !recipientId.isEmpty();
    if (text.startsWith("data:image/")) {
        QVariantMap placeholder;
        placeholder["sender"] = m_playerId;
        placeholder["senderNickname"] = m_nickname;
        placeholder["text"] = "Chargement de l'image...";
        placeholder["isImage"] = false;
        placeholder["isTextFile"] = false;
        placeholder["timestamp"] = ts;
        placeholder["isLoading"] = true;
        placeholder["ephemeral"] = isPrivate;
        if (isPrivate) {
            placeholder["recipientId"] = recipientId;
            placeholder["recipientNickname"] = recipientNickname;
        }
        m_messages.append(placeholder);
        emit messagesChanged();
        decodeImageAsync(m_playerId, text, ts);
    } else {
        const QString processedText = processMessageText(text);
        const bool isTextFile = processedText.startsWith("FILE:");
        QString fileExtension;
        if (isTextFile) {
            const int firstColon = processedText.indexOf(':', 3);
            if (firstColon > 3)
                fileExtension = processedText.mid(3, firstColon - 3);
        }
        QVariantMap msg;
        msg["sender"] = m_playerId;
        msg["senderNickname"] = m_nickname;
        msg["text"] = processedText;
        msg["isImage"] = processedText.startsWith("image://");
        msg["isTextFile"] = isTextFile;
        msg["fileExtension"] = fileExtension;
        msg["timestamp"] = ts;
        msg["ephemeral"] = isPrivate;
        if (isPrivate) {
            msg["recipientId"] = recipientId;
            msg["recipientNickname"] = recipientNickname;
        }
        m_messages.append(msg);
        emit messagesChanged();
    }
}

void ChatClient::sendImage(const QString &filePath) {
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    // Use QtConcurrent to process the image in a background thread
    QtConcurrent::run([this, filePath]() {
        Logger::instance()->debug(QString("Sending image (compressing in background...): %1").arg(filePath), "ChatClient");

        QUrl url(filePath);
        QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;

        QImage img(localPath);
        if (img.isNull()) {
            Logger::instance()->warn(QString("Could not load image: %1").arg(localPath), "ChatClient");
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

            Logger::instance()->debug(QString("Compressed image sent (Size: %1 KB)").arg(sizeKb), "ChatClient");
        }, Qt::QueuedConnection);
    });
}

void ChatClient::sendTextFile(const QString &filePath) {
    Logger::instance()->debug(QString("Sending text file: %1").arg(filePath), "ChatClient");
    if (!m_connected || m_sessionKeys.isEmpty()) return;

    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;

    QFileInfo fileInfo(localPath);
    if (!fileInfo.exists() || !fileInfo.isFile()) {
        Logger::instance()->warn(QString("File not found: %1").arg(localPath), "ChatClient");
        return;
    }

    // Limit file size to 1MB
    if (fileInfo.size() > 1024 * 1024) {
        Logger::instance()->warn(QString("File too large: %1 bytes (max 1MB)").arg(fileInfo.size()), "ChatClient");
        emit errorOccurred("Fichier trop volumineux (max 1MB)");
        return;
    }

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        Logger::instance()->warn(QString("Cannot open file: %1").arg(localPath), "ChatClient");
        return;
    }

    QString content = QString::fromUtf8(file.readAll());
    file.close();

    QString extension = fileInfo.suffix().toLower();
    QString fileName = fileInfo.fileName();

    // Format: 📄FILE:ext:filename\n\ncontenu
    QString formattedMessage = "FILE:" + extension + ":" + fileName + "\n\n" + content;

    // Encrypt and send using sendMessage
    sendMessage(formattedMessage);
    Logger::instance()->debug(QString("Text file sent: %1 (%2, %3 chars)").arg(fileName).arg(extension).arg(content.size()), "ChatClient");
}

void ChatClient::saveTextToFile(const QString &filePath, const QString &content) {
    QUrl url(filePath);
    QString localPath = url.isLocalFile() ? url.toLocalFile() : filePath;

    QFile file(localPath);
    if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
        file.write(content.toUtf8());
        file.close();
        Logger::instance()->debug(QString("File saved to: %1").arg(localPath), "ChatClient");
    } else {
        Logger::instance()->warn(QString("Failed to save file: %1").arg(localPath), "ChatClient");
        emit errorOccurred("Impossible de sauvegarder le fichier");
    }
}
