#include "CaseJail.h"
#include <QDebug>

CaseJail::CaseJail(const QString &name, int jailFine)
    : Case(name), m_jailFine(jailFine) {

    setType(Case::CS_Jail);
}

CaseJail::CaseJail(const QJsonObject &json, QObject *parent)
    : Case(json, parent)
{
    setType(Case::CS_Jail);
}

// void CaseJail::onLand(Player* player) {
    // if (!player->isInJail()) {
    //     sendToJail(player);
    //     qDebug() << "Player sent to Jail.";
    // } else {
    //     int turns = m_playersInJail[player];
    //     if (turns >= m_maxJailTurns || player->canAfford(m_jailFine)) {
    //         releasePlayer(player);
    //         qDebug() << "Player released from Jail.";
    //     } else {
    //         m_playersInJail[player]++;
    //         qDebug() << "Player remains in Jail for turn " << turns + 1;
    //     }
    // }
// }

void CaseJail::sendToJail(Player* player) {
    player->setInJail(true);
    m_playersInJail[player] = 0;
}

void CaseJail::releasePlayer(Player* player) {
    player->setInJail(false);
    m_playersInJail.remove(player);
    // Logic to move player out of jail, e.g., to the next position
}

QString CaseJail::toJSON()
{
    QString json;
    json = Case::toJSON();
    json.removeLast();
    json.removeLast();
    json+= ",\n";
    json += "    \"jailFine\": " + QString::number(m_jailFine) + ",\n";
    json += "}";
    return json;
} 
