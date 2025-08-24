#include "CaseCatDoor.h"
#include <QDebug>
#include "../player.h"


CaseCatDoor::CaseCatDoor(CASECATPERKS_DEFAULT_PARAMETER_NOP)
    : CASECATPERKS_DEFAULT_CONSTRUCS_PARAMETER
{
    setType(Case::CS_CatDoor);
}

CaseCatDoor::CaseCatDoor(const QString &json, QObject *parent)
    : CaseCatPerks(json, parent)
{
    setType(Case::CS_CatDoor);
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    QJsonObject obj = doc.object();
    m_name = obj["name"].toString();
    m_uniqueId = obj["uniqueId"].toInt();
    type = intToCaseType(obj["type"].toInt());
    m_indexCatDoor = obj["indexCatDoor"].toInt();
    m_travelPrice = obj["travelPrice"].toInt();
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

QString CaseCatDoor::toJSON()
{
    QString json;
    json = CaseCatPerks::toJSON();
    json.removeLast();
    json += "    \"indexCatDoor\": " + QString::number(m_indexCatDoor) + ",\n";
    json += "    \"travelPrice\": " + QString::number(m_travelPrice) + "\n";
    json += "}";
    return json;
}
