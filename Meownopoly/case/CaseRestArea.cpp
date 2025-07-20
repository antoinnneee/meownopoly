#include "CaseRestArea.h"
#include <QDebug>
#include "../player.h"


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


CaseRestArea::RestQuality CaseRestArea::restQuality() const
{
    return m_restQuality;
}

void CaseRestArea::setRestQuality(CaseRestArea::RestQuality newRestQuality)
{
    m_restQuality = newRestQuality;
}

FamilyType CaseRestArea::family() const
{
    return m_family;
}

void CaseRestArea::setFamily(FamilyType newFamily)
{
    m_family = newFamily;
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
