#include "CaseCatDoor.h"
#include <QDebug>
#include "../player.h"

CaseCatDoor::CaseCatDoor(QObject *parent)
    : CaseCatPerks("Cat Door", -1, parent)
{
    setType(CT_CatDoor);
}

CaseCatDoor::CaseCatDoor(const QString &name, int position, QObject *parent)
    : CaseCatPerks(name, position, parent)
{
    setType(CT_CatDoor);
}

bool CaseCatDoor::buyCase(Player *buyer)
{
    if (CaseCatPerks::buyCase(buyer)){
        buyer->addCatDoor(this);
        return true;
    }
    return false;
}

bool CaseCatDoor::sellCase(Player *buyer)
{
    CaseCatPerks::sellCase(buyer);
    buyer->removeCatDoor(this);
    return true;

    return false;

}

void CaseCatDoor::onLand(Player* player)
{
}


