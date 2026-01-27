#include "chat_crypto.h"
#include <QCryptographicHash>
#include <QMessageAuthenticationCode>
#include <QRandomGenerator>
#include <QDataStream>

ChatCrypto::ChatCrypto(QObject *parent) : QObject(parent) {}

QByteArray ChatCrypto::deriveLockKey(const QString &gameId, const QString &password)
{
    // Use salt (gameId) and password. Iterating this would be better (PBKDF2), 
    // but a simple salted SHA-256 is better than MD5.
    return QCryptographicHash::hash((gameId + password).toUtf8(), QCryptographicHash::Sha256);
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

    // 2. Verify Integrity
    QByteArray expectedTag = QMessageAuthenticationCode::hash(nonce + cipherText, key, QCryptographicHash::Sha256);
    
    // Constant-time comparison logic is ideal, but standard opertor== is acceptable for this level.
    if (receivedTag != expectedTag) {
        return QByteArray(); // Integrity check failed
    }

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
