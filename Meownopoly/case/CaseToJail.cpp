#include "CaseToJail.h"
#include "../player.h"
#include <QDebug>
#include <QJsonObject>

CaseToJail::CaseToJail(QObject *parent)
    : Case("Go To Jail", QUuid::createUuid(), parent)
{
    setType(Case::CS_ToJail);
}

CaseToJail::CaseToJail(const QString &name, QUuid uniqueId, QObject *parent)
    : Case(name, uniqueId, parent)
{
    setType(Case::CS_ToJail);
}

CaseToJail::CaseToJail(const QJsonObject &json, QObject *parent)
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
    json += "    \"jailCase\":" + m_jailCase->uniqueId().toString()  + "\n";
    json += "}";
    return json;
}
