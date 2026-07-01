#include "currency_module.h"

#include <QDebug>

CurrencyModule::CurrencyModule(QObject *parent)
    : GameplayModule(QStringLiteral("currency"), QStringLiteral("Module de monnaie"), parent)
{
}

void CurrencyModule::setStartingBalance(int balance)
{
    if (balance < 0)
        balance = 0;
    if (m_startingBalance == balance)
        return;
    m_startingBalance = balance;
    emit startingBalanceChanged();
}

int &CurrencyModule::balanceRef(const QString &playerId)
{
    auto it = m_balances.find(playerId);
    if (it == m_balances.end())
        it = m_balances.insert(playerId, m_startingBalance);
    return it.value();
}

int CurrencyModule::balance(const QString &playerId)
{
    return balanceRef(playerId);
}

bool CurrencyModule::hasPlayer(const QString &playerId) const
{
    return m_balances.contains(playerId);
}

bool CurrencyModule::registerPlayer(const QString &playerId, int amount)
{
    if (!enabled()) {
        qWarning() << "[CurrencyModule] registerPlayer ignoré — module désactivé";
        return false;
    }
    const int value = qMax(0, amount);
    m_balances.insert(playerId, value);
    emit balanceChanged(playerId, value);
    return true;
}

bool CurrencyModule::credit(const QString &playerId, int amount)
{
    if (!enabled()) {
        qWarning() << "[CurrencyModule] credit ignoré — module désactivé";
        return false;
    }
    if (amount <= 0)
        return false;
    int &bal = balanceRef(playerId);
    bal += amount;
    emit balanceChanged(playerId, bal);
    return true;
}

bool CurrencyModule::debit(const QString &playerId, int amount)
{
    if (!enabled()) {
        qWarning() << "[CurrencyModule] debit ignoré — module désactivé";
        return false;
    }
    if (amount <= 0)
        return false;
    int &bal = balanceRef(playerId);
    if (bal < amount) {
        emit transferFailed(playerId, QString(), amount,
                            QStringLiteral("solde insuffisant"));
        return false;
    }
    bal -= amount;
    emit balanceChanged(playerId, bal);
    return true;
}

bool CurrencyModule::transfer(const QString &fromId, const QString &toId, int amount)
{
    if (!enabled()) {
        qWarning() << "[CurrencyModule] transfer ignoré — module désactivé";
        return false;
    }
    if (amount <= 0)
        return false;
    if (fromId == toId) {
        emit transferFailed(fromId, toId, amount,
                            QStringLiteral("même joueur source et destination"));
        return false;
    }
    int &from = balanceRef(fromId);
    if (from < amount) {
        emit transferFailed(fromId, toId, amount,
                            QStringLiteral("solde insuffisant"));
        return false;
    }
    int &to = balanceRef(toId);
    from -= amount;
    to += amount;
    emit balanceChanged(fromId, from);
    emit balanceChanged(toId, to);
    return true;
}

void CurrencyModule::reset()
{
    m_balances.clear();
}
