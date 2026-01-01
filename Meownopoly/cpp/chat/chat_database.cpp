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
        qCritical() << "Failed to create chat table:" << query.lastError().text();
    }
    return ok;
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
