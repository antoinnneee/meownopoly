#include "account_manager.h"
#include <QSettings>
#include <QUuid>
#include <QDebug>
#include "../chat/chat_crypto.h"

AccountManager* AccountManager::s_instance = nullptr;

AccountManager::AccountManager(QObject *parent)
    : QObject(parent)
{
    loadAccount();
}

AccountManager::~AccountManager()
{
}

AccountManager* AccountManager::instance()
{
    if (!s_instance) {
        s_instance = new AccountManager();
    }
    return s_instance;
}

void AccountManager::loadAccount()
{
    QSettings settings;
    
    m_uniqueId = settings.value("account/uniqueId", "").toString();
    m_nickname = settings.value("account/nickname", "").toString();
    
    // Load private key from base64
    QString keyBase64 = settings.value("account/privateKey", "").toString();
    if (!keyBase64.isEmpty()) {
        m_privateKey = QByteArray::fromBase64(keyBase64.toUtf8());
    }
    
    // Load key creation date
    QString keyDateStr = settings.value("account/keyCreatedAt", "").toString();
    if (!keyDateStr.isEmpty()) {
        m_keyCreatedAt = QDateTime::fromString(keyDateStr, Qt::ISODate);
    }
    
    // Account exists if we have a unique ID
    bool hadAccount = m_hasAccount;
    m_hasAccount = !m_uniqueId.isEmpty();
    
    if (hadAccount != m_hasAccount) {
        emit hasAccountChanged();
    }
    
    qDebug() << "AccountManager: Loaded account -" 
             << "hasAccount:" << m_hasAccount 
             << "uniqueId:" << m_uniqueId 
             << "nickname:" << m_nickname;
}

void AccountManager::saveAccount()
{
    QSettings settings;
    
    settings.setValue("account/uniqueId", m_uniqueId);
    settings.setValue("account/nickname", m_nickname);
    settings.setValue("account/privateKey", QString::fromUtf8(m_privateKey.toBase64()));
    settings.setValue("account/keyCreatedAt", m_keyCreatedAt.toString(Qt::ISODate));
    
    settings.sync();
    
    qDebug() << "AccountManager: Saved account -"
             << "uniqueId:" << m_uniqueId
             << "nickname:" << m_nickname;
}

void AccountManager::setNickname(const QString &nickname)
{
    if (m_nickname != nickname) {
        m_nickname = nickname;
        saveAccount();
        emit nicknameChanged();
        qDebug() << "AccountManager: Nickname changed to" << m_nickname;
    }
}

void AccountManager::createAccount(const QString &nickname)
{
    if (m_hasAccount) {
        qWarning() << "AccountManager: Account already exists, cannot create another one";
        return;
    }
    
    // Generate unique ID
    generateUniqueId();
    
    // Set nickname
    m_nickname = nickname;
    
    // Generate cryptographic keys
    generateKeys();
    
    // Mark as having an account
    m_hasAccount = true;
    
    // Save everything
    saveAccount();
    
    emit nicknameChanged();
    emit hasAccountChanged();
    emit accountCreated();
    
    qDebug() << "AccountManager: Account created -"
             << "uniqueId:" << m_uniqueId
             << "nickname:" << m_nickname;
}

bool AccountManager::regenerateKeys()
{
    if (!m_hasAccount) {
        qWarning() << "AccountManager: No account exists, cannot regenerate keys";
        return false;
    }
    
    generateKeys();
    saveAccount();
    
    emit privateKeyChanged();
    emit keysRegenerated();
    
    qDebug() << "AccountManager: Keys regenerated at" << m_keyCreatedAt.toString(Qt::ISODate);
    return true;
}

void AccountManager::generateUniqueId()
{
    // Generate a UUID v4 and remove the braces
    m_uniqueId = QUuid::createUuid().toString(QUuid::WithoutBraces);
}

void AccountManager::generateKeys()
{
    // Use ChatCrypto to generate a random 256-bit key
    m_privateKey = ChatCrypto::generateRandomKey();
    m_keyCreatedAt = QDateTime::currentDateTime();
}
