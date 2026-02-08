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
    QString id;
    id.reserve(s_idLength);
    auto* rng = QRandomGenerator::global();
    for (int i = 0; i < s_idLength; ++i) {
        id.append(QChar(s_idChars[rng->bounded(s_idCharsCount)]));
    }
    m_uniqueId = id;
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
