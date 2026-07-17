#include "CaseCatDoor.h"
#include <QDebug>
#include "game/player.h"


CaseCatDoor::CaseCatDoor(CASECATPERKS_DEFAULT_PARAMETER_NOP)
    : CASECATPERKS_DEFAULT_CONSTRUCS_PARAMETER
{
    setType(Case::CS_CatDoor);
}

CaseCatDoor::CaseCatDoor(const QJsonObject &json, QObject *parent)
    : CaseCatPerks(json, parent)
{
    setType(Case::CS_CatDoor);
    
    m_indexCatDoor = json["indexCatDoor"].toInt();
    m_travelPrice = json["travelPrice"].toInt();
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

// void CaseCatDoor::onLand(Player* player)
// {
// }



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

QJsonObject CaseCatDoor::toJsonObject() const
{
    QJsonObject obj = CaseCatPerks::toJsonObject();
    obj["indexCatDoor"] = m_indexCatDoor;
    obj["travelPrice"] = m_travelPrice;
    return obj;
}
