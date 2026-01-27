#ifndef CHAT_DATABASE_H
#define CHAT_DATABASE_H

#include <QObject>
#include <QSqlDatabase>
#include <QVariantList>

class ChatDatabase : public QObject
{
    Q_OBJECT
public:
    explicit ChatDatabase(QObject *parent = nullptr);
    ~ChatDatabase();

    bool init();
    bool saveMessage(const QString &sessionId, const QString &senderId, const QByteArray &payload, const QByteArray &nonce, const QString &timestamp, int keyVersion);
    QVariantList getMessages(const QString &sessionId);
    
    // Key Persistence
    bool saveSessionKey(const QString &sessionId, int version, const QByteArray &keyBlob, const QByteArray &keyNonce);
    QMap<int, QByteArray> getSessionKeys(const QString &sessionId);

private:
    QSqlDatabase m_db;
};

#endif // CHAT_DATABASE_H
