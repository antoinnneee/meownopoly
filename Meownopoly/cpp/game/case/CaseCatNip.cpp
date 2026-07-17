#include "CaseCatNip.h"
#include <QDebug>
#include "game/player.h"

CaseCatNip::CaseCatNip(QObject *parent)
    : Case("Cat Nip", parent)
{
    setType(Case::CS_CatNip);
}

CaseCatNip::CaseCatNip(const QString &name, QObject *parent)
    : Case(name, parent)
{
    setType(Case::CS_CatNip);
}

CaseCatNip::CaseCatNip(const QJsonObject &json, QObject *parent)
    : Case(json, parent)
{
    setType(Case::CS_CatNip);
}


// void CaseCatNip::onLand(Player* player)
// {
//     Q_UNUSED(player);
//     qDebug() << "Player landed on Cat Nip";
//     // TODO: Implement chance card logic
// }
