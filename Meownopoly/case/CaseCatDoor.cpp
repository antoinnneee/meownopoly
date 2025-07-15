#include "CaseCatDoor.h"
#include <QDebug>
#include "../player.h"


CaseCatDoor::CaseCatDoor(const QString &name, int position, int price, int sellPrice, int morgagePrice, int travelPrice, int indexCatDoor, QObject *parent)
    : CaseCatPerks(name, position, price, sellPrice, morgagePrice, parent), m_travelPrice(travelPrice), m_indexCatDoor(indexCatDoor)
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



int CaseCatDoor::indexCatDoor() const
{
    return m_indexCatDoor;
}

void CaseCatDoor::setIndexCatDoor(int newIndexCatDoor)
{
    if (m_indexCatDoor == newIndexCatDoor)
        return;
    m_indexCatDoor = newIndexCatDoor;
    emit indexCatDoorChanged();
}

int CaseCatDoor::travelPrice() const
{
    return m_travelPrice;
}

void CaseCatDoor::setTravelPrice(int newTravelPrice)
{
    if (m_travelPrice == newTravelPrice)
        return;
    m_travelPrice = newTravelPrice;
    emit travelPriceChanged();
}
