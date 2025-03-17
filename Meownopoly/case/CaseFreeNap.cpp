#include "CaseFreeNap.h"
#include <QDebug>
#include "../player.h"

CaseFreeNap::CaseFreeNap(QObject *parent)
    : Case("Free Nap", -1, parent)
{
    setType(CT_FreeNap);
}

CaseFreeNap::CaseFreeNap(const QString &name, int position, QObject *parent)
    : Case(name, position, parent)
{
    setType(CT_FreeNap);
}

int CaseFreeNap::poolMoney() const
{
    return m_poolMoney;
}

void CaseFreeNap::setPoolMoney(int amount)
{
    m_poolMoney = amount;
}

void CaseFreeNap::addToPool(int amount)
{
    m_poolMoney += amount;
}

void CaseFreeNap::onLand(Player* player)
{
    qDebug() << "Player landed on Free Nap, collecting" << m_poolMoney << "kibble";
    if (m_poolMoney > 0) {
        player->earnKibble(m_poolMoney);
        m_poolMoney = 0;  // Reset pool after collection
    }
}
