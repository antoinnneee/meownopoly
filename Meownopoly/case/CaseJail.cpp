#include "CaseJail.h"
#include <QDebug>

CaseJail::CaseJail(const QString &name, int position, int jailFine)
    : Case(name, position), m_jailFine(jailFine) {}

void CaseJail::onLand(Player* player) {
    if (!player->isInJail()) {
        sendToJail(player);
        qDebug() << "Player sent to Jail.";
    } else {
        int turns = m_playersInJail[player];
        if (turns >= m_maxJailTurns || player->canAfford(m_jailFine)) {
            releasePlayer(player);
            qDebug() << "Player released from Jail.";
        } else {
            m_playersInJail[player]++;
            qDebug() << "Player remains in Jail for turn " << turns + 1;
        }
    }
}

void CaseJail::sendToJail(Player* player) {
    player->setPosition(position());
    player->setInJail(true);
    m_playersInJail[player] = 0;
}

void CaseJail::releasePlayer(Player* player) {
    player->setInJail(false);
    m_playersInJail.remove(player);
    // Logic to move player out of jail, e.g., to the next position
} 