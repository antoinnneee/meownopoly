#include "CaseFreeNap.h"
#include <QDebug>
#include "../player.h"

CaseFreeNap::CaseFreeNap(QObject *parent)
    : Case("Free Nap", QUuid::createUuid(), parent)
{
    setType(Case::CS_FreeNap);
}

CaseFreeNap::CaseFreeNap(const QString &name, QUuid uniqueId, QObject *parent)
    : Case(name, uniqueId, parent)
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

QString CaseFreeNap::toJSON()
{
    QString json;
    json = Case::toJSON();
    json.removeLast();
    json.removeLast();
    json+= ",\n";
    json += "    \"kibbleAmount\": " + QString::number(m_kibbleAmount) + "\n";
    json += "}";
    return json;
}
