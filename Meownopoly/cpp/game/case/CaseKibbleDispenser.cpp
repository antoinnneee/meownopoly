#include "CaseKibbleDispenser.h"
#include <QDebug>
#include "game/player.h"

CaseKibbleDispenser::CaseKibbleDispenser(QObject *parent)
    : Case("Kibble Dispenser", parent)
{
    setType(Case::CS_KibbleDispenser);

}

CaseKibbleDispenser::CaseKibbleDispenser(const QString &name, int reward, QObject *parent)
    : Case(name, parent), m_reward(reward)
{
    setType(Case::CS_KibbleDispenser);
}

CaseKibbleDispenser::CaseKibbleDispenser(const QJsonObject &json, QObject *parent)
    : Case(json, parent)
{
    setType(Case::CS_KibbleDispenser);
    
    m_reward = json["reward"].toInt();
}

int CaseKibbleDispenser::reward() const {
    return m_reward;
}

void CaseKibbleDispenser::setReward(int newReward) {
    m_reward = newReward;
    emit rewardChanged();
}

// void CaseKibbleDispenser::onLand(Player* player)
// {
//     qDebug() << "Player landed on Kibble Dispenser and received" << m_reward << "kibble";
//     player->earnKibble(m_reward);
// }

QJsonObject CaseKibbleDispenser::toJsonObject() const
{
    QJsonObject obj = Case::toJsonObject();
    obj["reward"] = m_reward;
    return obj;
}
