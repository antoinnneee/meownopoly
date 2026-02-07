#include "chat_database.h"
#include <QSqlQuery>
#include <QSqlError>
#include <QStandardPaths>
#include <QDir>
#include <QDebug>

ChatDatabase::ChatDatabase(QObject *parent) : QObject(parent) {}

ChatDatabase::~ChatDatabase() {
    if (m_db.isOpen()) {
        m_db.close();
    }
}

bool ChatDatabase::init()
{
    QString dbPath = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(dbPath);
    dbPath += "/local_chat.db";

    m_db = QSqlDatabase::addDatabase("QSQLITE", "ChatConnection");
    m_db.setDatabaseName(dbPath);

    if (!m_db.open()) {
        qCritical() << "Failed to open chat database:" << m_db.lastError().text();
        return false;
    }

    QSqlQuery query(m_db);
    bool ok = query.exec("CREATE TABLE IF NOT EXISTS local_history ("
                         "msg_id INTEGER PRIMARY KEY AUTOINCREMENT,"
                         "session_id TEXT,"
                         "sender_id TEXT,"
                         "sender_nickname TEXT,"
                         "encrypted_payload BLOB,"
                         "nonce BLOB,"
                         "timestamp TEXT,"
                         "key_version INTEGER"
                         ")");
    if (!ok) {
        qCritical() << "Failed to create chat table (local_history):" << query.lastError().text();
        return false;
    }

    query.exec("ALTER TABLE local_history ADD COLUMN key_version INTEGER DEFAULT 1");
    query.exec("ALTER TABLE local_history ADD COLUMN sender_nickname TEXT");

    ok = query.exec("CREATE TABLE IF NOT EXISTS session_keys ("
                    "session_id TEXT,"
                    "version INTEGER,"
                    "key_blob BLOB,"
                    "nonce BLOB,"
                    "PRIMARY KEY (session_id, version))");
    if (!ok) {
        qCritical() << "Failed to create chat table (session_keys):" << query.lastError().text();
        return false;
    }

    return true;
}

bool ChatDatabase::saveMessage(const QString &sessionId, const QString &senderId, const QString &senderNickname, const QByteArray &payload, const QByteArray &nonce, const QString &timestamp, int keyVersion)
{
    QSqlQuery query(m_db);
    query.prepare("INSERT INTO local_history (session_id, sender_id, sender_nickname, encrypted_payload, nonce, timestamp, key_version) "
                  "VALUES (:sid, :sender, :nick, :payload, :nonce, :ts, :kv)");
    query.bindValue(":sid", sessionId);
    query.bindValue(":sender", senderId);
    query.bindValue(":nick", senderNickname);
    query.bindValue(":payload", payload);
    query.bindValue(":nonce", nonce);
    query.bindValue(":ts", timestamp);
    query.bindValue(":kv", keyVersion);

    if (!query.exec()) {
        qCritical() << "Failed to save message:" << query.lastError().text();
        return false;
    }
    return true;
}

bool ChatDatabase::clearMessages(const QString &sessionId)
{
    QSqlQuery query(m_db);
    query.prepare("DELETE FROM local_history WHERE session_id = :sid");
    query.bindValue(":sid", sessionId);

    if (!query.exec()) {
        qCritical() << "Failed to clear messages:" << query.lastError().text();
        return false;
    }
    return true;
}

QVariantList ChatDatabase::getMessages(const QString &sessionId)
{
    QVariantList messages;
    QSqlQuery query(m_db);
    query.prepare("SELECT sender_id, sender_nickname, encrypted_payload, nonce, timestamp, key_version FROM local_history WHERE session_id = :sid ORDER BY timestamp ASC");
    query.bindValue(":sid", sessionId);

    if (query.exec()) {
        while (query.next()) {
            QVariantMap msg;
            msg["sender_id"] = query.value(0).toString();
            msg["sender_nickname"] = query.value(1).toString();
            msg["payload"] = query.value(2).toByteArray();
            msg["nonce"] = query.value(3).toByteArray();
            msg["timestamp"] = query.value(4).toString();
            msg["key_version"] = query.value(5).toInt();
            messages.append(msg);
        }
    }
    return messages;
}

bool ChatDatabase::saveSessionKey(const QString &sessionId, int version, const QByteArray &keyBlob, const QByteArray &keyNonce) {
    QSqlQuery query(m_db);
    query.prepare("INSERT OR REPLACE INTO session_keys (session_id, version, key_blob, nonce) VALUES (:sid, :ver, :blob, :nonce)");
    query.bindValue(":sid", sessionId);
    query.bindValue(":ver", version);
    query.bindValue(":blob", keyBlob);
    query.bindValue(":nonce", keyNonce);
    
    if (!query.exec()) {
        qCritical() << "Failed to save session key:" << query.lastError().text();
        return false;
    }
    return true;
}

QMap<int, QByteArray> ChatDatabase::getSessionKeys(const QString &sessionId) {
    QMap<int, QByteArray> keys;
    QSqlQuery query(m_db);
    query.prepare("SELECT version, key_blob, nonce FROM session_keys WHERE session_id = :sid");
    query.bindValue(":sid", sessionId);
    
    if (query.exec()) {
        while (query.next()) {
            // Pack blob + nonce together for the caller to decrypt
            QByteArray blob = query.value("key_blob").toByteArray();
            QByteArray nonce = query.value("nonce").toByteArray();
            
            QByteArray combined;
            QDataStream stream(&combined, QIODevice::WriteOnly);
            stream << blob << nonce;
            
            keys.insert(query.value("version").toInt(), combined);
        }
    } else {
        qCritical() << "Failed to load session keys:" << query.lastError().text();
    }
    return keys;
}
