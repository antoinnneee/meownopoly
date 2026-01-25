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
                         "encrypted_payload BLOB,"
                         "nonce BLOB,"
                         "timestamp TEXT"
                         ")");
    if (!ok) {
        qCritical() << "Failed to create chat table (local_history):" << query.lastError().text();
        return false;
    }

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

bool ChatDatabase::saveMessage(const QString &sessionId, const QString &senderId, const QByteArray &payload, const QByteArray &nonce, const QString &timestamp)
{
    QSqlQuery query(m_db);
    query.prepare("INSERT INTO local_history (session_id, sender_id, encrypted_payload, nonce, timestamp) "
                  "VALUES (:sid, :sender, :payload, :nonce, :ts)");
    query.bindValue(":sid", sessionId);
    query.bindValue(":sender", senderId);
    query.bindValue(":payload", payload);
    query.bindValue(":nonce", nonce);
    query.bindValue(":ts", timestamp);

    if (!query.exec()) {
        qCritical() << "Failed to save message:" << query.lastError().text();
        return false;
    }
    return true;
}

QVariantList ChatDatabase::getMessages(const QString &sessionId)
{
    QVariantList messages;
    QSqlQuery query(m_db);
    query.prepare("SELECT sender_id, encrypted_payload, nonce, timestamp FROM local_history WHERE session_id = :sid ORDER BY timestamp ASC");
    query.bindValue(":sid", sessionId);

    if (query.exec()) {
        while (query.next()) {
            QVariantMap msg;
            msg["sender_id"] = query.value(0).toString();
            msg["payload"] = query.value(1).toByteArray();
            msg["nonce"] = query.value(2).toByteArray();
            msg["timestamp"] = query.value(3).toString();
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
