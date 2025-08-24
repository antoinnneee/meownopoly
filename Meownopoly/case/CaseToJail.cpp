#include "CaseToJail.h"
#include "../player.h"
#include <QDebug>
#include <QJsonObject>

CaseToJail::CaseToJail(QObject *parent)
    : Case("Go To Jail", -1, parent)
{
    setType(Case::CS_ToJail);
}

CaseToJail::CaseToJail(const QString &name, int uniqueId, QObject *parent)
    : Case(name, uniqueId, parent)
{
    setType(Case::CS_ToJail);
}

CaseToJail::CaseToJail(const QString &json, QObject *parent)
    : Case(json, parent)
{
    setType(Case::CS_ToJail);
}

// void CaseToJail::onLand(Player* player) {
//     if (m_jailCase) {
//         m_jailCase->sendToJail(player);
//         qDebug() << "Player sent directly to Jail.";
//     } else {
//         qDebug() << "Warning: Jail case not set, cannot send player to jail.";
//         player->setInJail(true);
//     }
// }

void CaseToJail::setJailCase(CaseJail* jailCase) {
    m_jailCase = jailCase;
}

QString CaseToJail::toJSON()
{
    QString json;
    json = Case::toJSON();
    json.removeLast();
    json += "    \"jailCase\": " + QString::number(m_jailCase->uniqueId()) + "\n";
    json += "}";
    return json;
}
