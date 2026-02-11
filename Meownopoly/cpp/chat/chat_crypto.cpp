#include "chat_crypto.h"
#include <QCryptographicHash>
#include <QMessageAuthenticationCode>
#include <QRandomGenerator>
#include <QDataStream>

ChatCrypto::ChatCrypto(QObject *parent) : QObject(parent) {}

// Dérivation de la clé de verrouillage (session + mot de passe).
// SHA256 salé : compatible avec les sessions existantes. Pour plus de résistance au bruteforce,
// on pourrait passer à PBKDF2-HMAC-SHA256 avec un "key derivation version" dans le protocole.
QByteArray ChatCrypto::deriveLockKey(const QString &gameId, const QString &password)
{
    return QCryptographicHash::hash((gameId + password).toUtf8(), QCryptographicHash::Sha256);
}

QByteArray ChatCrypto::derivePasswordProof(const QString &sessionId, const QString &password)
{
    // High-entropy proof that password is correct without sending the password itself
    // Salted with a static string to differentiate from the lock key
    return QCryptographicHash::hash((password + sessionId + "proof-salt").toUtf8(), QCryptographicHash::Sha256).toHex();
}

QByteArray ChatCrypto::generateNonce()
{
    // Use System Random (CSPRNG)
    QByteArray nonce(12, 0);
    QRandomGenerator::system()->fillRange(reinterpret_cast<quint32*>(nonce.data()), 3);
    return nonce;
}

QByteArray ChatCrypto::generateRandomKey()
{
    // Use System Random (CSPRNG)
    QByteArray key(32, 0);
    QRandomGenerator::system()->fillRange(reinterpret_cast<quint32*>(key.data()), 8);
    return key;
}

// Helper for stream cipher: Keystream = SHA256(Key + Nonce + Counter)
static QByteArray generateKeystreamBlock(const QByteArray &key, const QByteArray &nonce, quint32 counter)
{
    QByteArray input = key + nonce + QByteArray::number(counter);
    return QCryptographicHash::hash(input, QCryptographicHash::Sha256);
}

QByteArray ChatCrypto::encrypt(const QByteArray &data, const QByteArray &key, const QByteArray &nonce)
{
    if (key.isEmpty() || nonce.isEmpty()) return QByteArray();

    // 1. Encrypt (Stream Cipher style)
    QByteArray cipherText;
    cipherText.reserve(data.size());
    
    QByteArray keystream;
    int blockIndex = 0;
    
    for (int i = 0; i < data.size(); ++i) {
        if (i % 32 == 0) {
            keystream = generateKeystreamBlock(key, nonce, blockIndex++);
        }
        cipherText.append(data[i] ^ keystream[i % 32]);
    }

    // 2. Authenticate (HMAC-SHA256)
    // Tag = HMAC(Key, Nonce + Ciphertext)
    QByteArray tag = QMessageAuthenticationCode::hash(nonce + cipherText, key, QCryptographicHash::Sha256);

    // Result: [Tag (32 bytes)] + [Ciphertext]
    return tag + cipherText;
}

QByteArray ChatCrypto::decrypt(const QByteArray &encryptedData, const QByteArray &key, const QByteArray &nonce)
{
    if (key.isEmpty() || nonce.isEmpty() || encryptedData.size() < 32) return QByteArray();

    // 1. Separate Tag and Ciphertext
    QByteArray receivedTag = encryptedData.left(32);
    QByteArray cipherText = encryptedData.mid(32);

    // 2. Verify Integrity (constant-time to avoid timing attacks)
    QByteArray expectedTag = QMessageAuthenticationCode::hash(nonce + cipherText, key, QCryptographicHash::Sha256);
    if (receivedTag.size() != expectedTag.size()) return QByteArray();
    quint8 diff = 0;
    for (int i = 0; i < receivedTag.size(); ++i)
        diff |= static_cast<quint8>(receivedTag[i]) ^ static_cast<quint8>(expectedTag[i]);
    if (diff != 0) return QByteArray();

    // 3. Decrypt
    QByteArray plainText;
    plainText.reserve(cipherText.size());
    
    QByteArray keystream;
    int blockIndex = 0;
    
    for (int i = 0; i < cipherText.size(); ++i) {
        if (i % 32 == 0) {
            keystream = generateKeystreamBlock(key, nonce, blockIndex++);
        }
        plainText.append(cipherText[i] ^ keystream[i % 32]);
    }

    return plainText;
}
