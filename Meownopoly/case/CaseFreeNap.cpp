#include "CaseFreeNap.h"
#include <QDebug>
#include "../player.h"

CaseFreeNap::CaseFreeNap(QObject *parent)
    : Case("Free Nap", -1, parent)
{
    setType(Case::CS_FreeNap);
}

CaseFreeNap::CaseFreeNap(const QString &name, int position, QObject *parent)
    : Case(name, position, parent)
{
    setType(Case::CS_FreeNap);
}

void CaseFreeNap::addToPool(int amount)
{
    setKibbleAmount(m_kibbleAmount + amount);

}

// void CaseFreeNap::onLand(Player* player)
// {
//     qDebug() << "Player" << player->name()<<" landed on Free Nap, collecting" << m_kibbleAmount << "kibble (todo)";
// }

int CaseFreeNap::kibbleAmount() const
{
    return m_kibbleAmount;
}

void CaseFreeNap::setKibbleAmount(int newKibbleAmount)
{
    if (m_kibbleAmount == newKibbleAmount)
        return;
    m_kibbleAmount = newKibbleAmount;
    emit kibbleAmountChanged();
}
