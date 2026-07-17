#include "CaseFreeNap.h"
#include <QDebug>
#include "game/player.h"

CaseFreeNap::CaseFreeNap(QObject *parent)
    : Case("Free Nap", parent)
{
    setType(Case::CS_FreeNap);
}

CaseFreeNap::CaseFreeNap(const QString &name, QObject *parent)
    : Case(name, parent)
{
    setType(Case::CS_FreeNap);
}

CaseFreeNap::CaseFreeNap(const QJsonObject &json, QObject *parent)
    : Case(json, parent)
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

QJsonObject CaseFreeNap::toJsonObject() const
{
    QJsonObject obj = Case::toJsonObject();
    obj["kibbleAmount"] = m_kibbleAmount;
    return obj;
}
