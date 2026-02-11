#ifndef CHAT_CRYPTO_H
#define CHAT_CRYPTO_H

#include <QObject>
#include <QByteArray>
#include <QString>

class ChatCrypto : public QObject
{
    Q_OBJECT
public:
    explicit ChatCrypto(QObject *parent = nullptr);

    static QByteArray deriveLockKey(const QString &gameId, const QString &password);
    static QByteArray derivePasswordProof(const QString &sessionId, const QString &password);
    
    // AES-256-GCM Encryption/Decryption
    // Result is [payload + auth_tag] or just decrypted payload
    static QByteArray encrypt(const QByteArray &data, const QByteArray &key, const QByteArray &nonce);
    static QByteArray decrypt(const QByteArray &encryptedData, const QByteArray &key, const QByteArray &nonce);

    static QByteArray generateNonce();
    static QByteArray generateRandomKey();
};

#endif // CHAT_CRYPTO_H
