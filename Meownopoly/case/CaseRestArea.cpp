#include "CaseRestArea.h"
#include <QDebug>
#include "../player.h"

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
    setType(Case::CS_RestArea);
}

CaseRestArea::CaseRestArea(CASECATPERKS_DEFAULT_PARAMETER_NOP, FamilyType family, int housePrice, int hotelPrice, QList<int> rentPrice)
    : CASECATPERKS_DEFAULT_CONSTRUCS_PARAMETER, m_family(family), m_housePrice(housePrice), m_hotelPrice(hotelPrice), m_rentPrice(rentPrice)

{
    setType(Case::CS_RestArea);
}

CaseRestArea::CaseRestArea(const QJsonDocument &json, QObject *parent)
    : CaseCatPerks(json, parent)
{
    setType(Case::CS_RestArea);

    QJsonObject obj = json.object();
    m_restQuality = (enum RestQuality) obj["restQuality"].toInt();
    m_family = (enum FamilyType) obj["family"].toInt();
    m_housePrice = obj["housePrice"].toInt();
    m_hotelPrice = obj["hotelPrice"].toInt();
    QJsonArray rentPriceArray = obj["rentPrice"].toArray();
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

QString CaseRestArea::toJSON()
{
    QString json;
    json = CaseCatPerks::toJSON();
    json.removeLast();
    json += "    \"restQuality\": " + QString::number(m_restQuality) + ",\n";
    json += "    \"family\": " + QString::number(m_family) + ",\n";
    json += "    \"housePrice\": " + QString::number(m_housePrice) + ",\n";
    json += "    \"hotelPrice\": " + QString::number(m_hotelPrice) + ",\n";
    json += "    \"rentPrice\": [";
    for (int i = 0; i < m_rentPrice.size(); i++) {
        json += QString::number(m_rentPrice.at(i)) + (i < m_rentPrice.size() - 1 ? ", " : "");
    }
    json += "]\n";
    json += "}";
    return json;
}
