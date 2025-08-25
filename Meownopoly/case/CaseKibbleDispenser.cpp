#include "CaseKibbleDispenser.h"
#include <QDebug>
#include "../player.h"

CaseKibbleDispenser::CaseKibbleDispenser(QObject *parent)
    : Case("Kibble Dispenser", QUuid::createUuid(), parent)
{
    setType(Case::CS_KibbleDispenser);

}

CaseKibbleDispenser::CaseKibbleDispenser(const QString &name, QUuid id, int reward, QObject *parent)
    : Case(name, id, parent), m_reward(reward)
{
    setType(Case::CS_KibbleDispenser);
}

CaseKibbleDispenser::CaseKibbleDispenser(const QJsonDocument &json, QObject *parent)
    : Case(json, parent)
{
    setType(Case::CS_KibbleDispenser);
    
    QJsonObject obj = json.object();
    m_reward = obj["reward"].toInt();
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

QString CaseKibbleDispenser::toJSON()
{
    QString json;
    json = Case::toJSON();
    json.removeLast();
    json += "    \"reward\": " + QString::number(m_reward) + "\n";
    json += "}";
    return json;
}
