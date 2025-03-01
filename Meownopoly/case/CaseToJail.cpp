#include "CaseToJail.h"
#include "../player.h"
#include <QDebug>

CaseToJail::CaseToJail(QObject *parent)
    : Case("Go To Jail", -1, parent)
{
    setType(CT_ToJail);
}

CaseToJail::CaseToJail(const QString &name, int position, QObject *parent)
    : Case(name, position, parent)
{
    setType(CT_ToJail);
}

void CaseToJail::onLand(Player* player) {
    if (m_jailCase) {
        m_jailCase->sendToJail(player);
        qDebug() << "Player sent directly to Jail.";
    } else {
        qDebug() << "Warning: Jail case not set, cannot send player to jail.";
        player->setInJail(true);
    }
}

void CaseToJail::setJailCase(CaseJail* jailCase) {
    m_jailCase = jailCase;
} 