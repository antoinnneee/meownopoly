#include "CaseRestArea.h"
#include <QDebug>
#include "game/player.h"

#include <QJsonDocument>
#include <QJsonArray>


// CaseRestArea::CaseRestArea(CASECATPERKS_DEFAULT_PARAMETER_NOP)
//     : CASECATPERKS_DEFAULT_CONSTRUCS_PARAMETER
// {
//     setType(Case::CS_RestArea);
// }


CaseRestArea::CaseRestArea(QObject *parent)
    : CaseCatPerks("Unknown Rest Area")
{
    Q_UNUSED(parent)
    setType(Case::CS_RestArea);
}

CaseRestArea::CaseRestArea(CASECATPERKS_DEFAULT_PARAMETER_NOP, FamilyType family, int housePrice, int hotelPrice, QList<int> rentPrice)
    : CASECATPERKS_DEFAULT_CONSTRUCS_PARAMETER, m_family(family), m_housePrice(housePrice), m_hotelPrice(hotelPrice), m_rentPrice(rentPrice)

{
    setType(Case::CS_RestArea);
}

CaseRestArea::CaseRestArea(const QJsonObject &json, QObject *parent)
    : CaseCatPerks(json, parent)
{
    setType(Case::CS_RestArea);

    m_restQuality = (enum RestQuality) json["restQuality"].toInt();
    m_family = (enum FamilyType) json["family"].toInt();
    m_housePrice = json["housePrice"].toInt();
    m_hotelPrice = json["hotelPrice"].toInt();
    QJsonArray rentPriceArray = json["rentPrice"].toArray();
    for (const QJsonValue &value : rentPriceArray) {
        m_rentPrice.append(value.toInt());
    }
}


CaseRestArea::RestQuality CaseRestArea::restQuality() const
{
    return m_restQuality;
}

void CaseRestArea::setRestQuality(CaseRestArea::RestQuality newRestQuality)
{
    m_restQuality = newRestQuality;
    emit restQualityChanged();
}

CaseRestArea::FamilyType CaseRestArea::family() const
{
    return m_family;
}

void CaseRestArea::setFamily(CaseRestArea::FamilyType newFamily)
{
    m_family = newFamily;
    emit familyChanged();
}



// void CaseRestArea::print_state()
// {
//     qDebug() << "Quality[" << m_restQuality << "] name[" << name() << "] price[" << m_prices <<"] family[" << m_family << "]";
// }



bool CaseRestArea::buyCase(Player *buyer) {
    if (CaseCatPerks::buyCase(buyer)){
        buyer->addProperty(this);
        return true;
    }
    return false;
}

bool CaseRestArea::sellCase(Player *buyer)
{
    CaseCatPerks::sellCase(buyer);
    buyer->removeProperty(this);
    return true;
}

int CaseRestArea::housePrice() const
{
    return m_housePrice;
}

void CaseRestArea::setHousePrice(int newHousePrice)
{
    if (m_housePrice == newHousePrice)
        return;
    m_housePrice = newHousePrice;
    emit housePriceChanged();
}

int CaseRestArea::hotelPrice() const
{
    return m_hotelPrice;
}

void CaseRestArea::setHotelPrice(int newHotelPrice)
{
    if (m_hotelPrice == newHotelPrice)
        return;
    m_hotelPrice = newHotelPrice;
    emit hotelPriceChanged();
}

QList<int> CaseRestArea::rentPrice() const
{
    return m_rentPrice;
}

void CaseRestArea::setRentPrice(const QList<int> &newRentPrice)
{
    if (m_rentPrice == newRentPrice)
        return;
    m_rentPrice = newRentPrice;
    emit rentPriceChanged();
}

QJsonObject CaseRestArea::toJsonObject() const
{
    QJsonObject obj = CaseCatPerks::toJsonObject();
    obj["restQuality"] = static_cast<int>(m_restQuality);
    obj["family"] = static_cast<int>(m_family);
    obj["housePrice"] = m_housePrice;
    obj["hotelPrice"] = m_hotelPrice;
    QJsonArray rentArray;
    for (int rent : m_rentPrice)
        rentArray.append(rent);
    obj["rentPrice"] = rentArray;
    return obj;
}
