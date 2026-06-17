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
    
    // Chiffrement authentifié (encrypt-then-MAC) : stream cipher maison
    // (keystream = SHA-256(key + nonce + counter)) + tag HMAC-SHA-256.
    // encrypt() retourne [tag 32 octets][ciphertext] ; decrypt() vérifie le
    // tag en temps constant et retourne le clair, ou QByteArray() si invalide.
    // Doit rester aligné avec le miroir JS chatServer/chat_crypto.js.
    static QByteArray encrypt(const QByteArray &data, const QByteArray &key, const QByteArray &nonce);
    static QByteArray decrypt(const QByteArray &encryptedData, const QByteArray &key, const QByteArray &nonce);

    static QByteArray generateNonce();
    static QByteArray generateRandomKey();
};

#endif // CHAT_CRYPTO_H
