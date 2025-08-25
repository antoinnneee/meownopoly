#include "CaseCatNip.h"
#include <QDebug>
#include "../player.h"

CaseCatNip::CaseCatNip(QObject *parent)
    : Case("Cat Nip", QUuid::createUuid(), parent)
{
    setType(Case::CS_CatNip);
}

CaseCatNip::CaseCatNip(const QString &name, QUuid uniqueId, QObject *parent)
    : Case(name, uniqueId, parent)
{
    setType(Case::CS_CatNip);
}

CaseCatNip::CaseCatNip(const QJsonObject &json, QObject *parent)
    : Case(json, parent)
{
    setType(Case::CS_CatNip);
}

QString CaseCatNip::toJSON()
{
    QString json;
    json = Case::toJSON();
    json.removeLast();
    json.removeLast();
    json += "\n}";
    return json;
}


// void CaseCatNip::onLand(Player* player)
// {
//     Q_UNUSED(player);
//     qDebug() << "Player landed on Cat Nip";
//     // TODO: Implement chance card logic
// }
