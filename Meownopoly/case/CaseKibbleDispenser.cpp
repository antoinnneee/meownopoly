#include "CaseKibbleDispenser.h"
#include <QDebug>
#include "../player.h"

CaseKibbleDispenser::CaseKibbleDispenser(QObject *parent)
    : Case("Kibble Dispenser", -1, parent)
{
    setType(Case::CS_KibbleDispenser);

}

CaseKibbleDispenser::CaseKibbleDispenser(const QString &name, int position, int reward, QObject *parent)
    : Case(name, position, parent), m_reward(reward)
{
    setType(Case::CS_KibbleDispenser);
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
