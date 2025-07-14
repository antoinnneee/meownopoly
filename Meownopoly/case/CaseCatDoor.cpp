#include "CaseCatDoor.h"
#include <QDebug>
#include "../player.h"

CaseCatDoor::CaseCatDoor(QObject *parent)
    : Case("Cat Door", -1, parent)
{
    setType(CT_CatDoor);
}

CaseCatDoor::CaseCatDoor(const QString &name, int position, QObject *parent)
    : Case(name, position, parent)
{
    setType(CT_CatDoor);
}

void CaseCatDoor::onLand(Player* player)
{
} 
