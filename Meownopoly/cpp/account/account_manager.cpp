#include "account_manager.h"
#include <QSettings>
#include <QRandomGenerator>
#include <QDebug>

static const char s_idChars[] = "0123456789abcdefghijklmnopqrstuvwxyz";
static const int s_idCharsCount = 36;
static const int s_idLength = 8;

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
    m_stunServer = settings.value("account/stunServer", "pattouncorp.ovh").toString();
    m_stunPort = settings.value("account/stunPort", 3000).toUInt();
    
    // Account exists if we have a unique ID
    bool hadAccount = m_hasAccount;
    m_hasAccount = !m_uniqueId.isEmpty();
    
    if (hadAccount != m_hasAccount) {
        emit hasAccountChanged();
    }
    
    qDebug() << "AccountManager: Loaded account -" 
             << "hasAccount:" << m_hasAccount 
             << "uniqueId:" << m_uniqueId 
             << "nickname:" << m_nickname
             << "stunServer:" << m_stunServer
             << "stunPort:" << m_stunPort;
}

void AccountManager::saveAccount()
{
    QSettings settings;
    
    settings.setValue("account/uniqueId", m_uniqueId);
    settings.setValue("account/nickname", m_nickname);
    settings.setValue("account/stunServer", m_stunServer);
    settings.setValue("account/stunPort", m_stunPort);
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

void AccountManager::setStunServerURL(const QString &server)
{
    if (m_stunServer != server) {
        m_stunServer = server;
        saveAccount();
        emit stunServerChanged();
        qDebug() << "AccountManager: STUN server changed to" << m_stunServer;
    }
}

void AccountManager::setStunPort(quint16 port)
{
    if (m_stunPort != port) {
        m_stunPort = port;
        saveAccount();
        emit stunPortChanged();
        qDebug() << "AccountManager: STUN port changed to" << m_stunPort;
    }
}

void AccountManager::createAccount(const QString &nickname)
{
    if (m_hasAccount) {
        qWarning() << "AccountManager: Account already exists, cannot create another one";
        return;
    }
    
    generateUniqueId();
    m_nickname = nickname;
    
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

void AccountManager::generateUniqueId()
{
    m_uniqueId = getNewUniqueId();
}

bool AccountManager::regenerateUniqueId()
{
    if (!m_hasAccount) {
        qWarning() << "AccountManager: No account, cannot regenerate unique ID";
        return false;
    }
    generateUniqueId();
    saveAccount();
    emit uniqueIdChanged();
    qDebug() << "AccountManager: Unique ID regenerated:" << m_uniqueId;
    return true;
}

QString AccountManager::getNewUniqueId()
{
    QString id;
    id.reserve(s_idLength);
    auto* rng = QRandomGenerator::global();
    for (int i = 0; i < s_idLength; ++i) {
        id.append(QChar(s_idChars[rng->bounded(s_idCharsCount)]));
    }
    return id;
}
