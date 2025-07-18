#include "CaseCatPerks.h"
#include "../player.h"


// CaseCatPerks::CaseCatPerks(const QString &name, int position, int price, int sellPrice, int morgagePrice, QObject *parent) :  Case::Case(name, position, parent), m_morgagePrice(morgagePrice){

// }

CaseCatPerks::CaseCatPerks(const QString &name, int position, int morgagePrice, int price, int sellPrice, QObject *parent)
{

}

bool CaseCatPerks::buyCase(Player *buyer)
{
    return buyer->spendKibble(price());
}

void CaseCatPerks::sellCase(Player *buyer)
{
    return buyer->earnKibble(sellPrice());
}


int CaseCatPerks::price() const
{
    return m_price;
}

void CaseCatPerks::setPrice(int newPrice)
{
    if (m_price == newPrice)
        return;
    m_price = newPrice;
    emit priceChanged();
}

int CaseCatPerks::sellPrice() const
{
    return m_sellPrice;
}

void CaseCatPerks::setsellPrice(int newSellPrice)
{
    if (m_sellPrice == newSellPrice)
        return;
    m_sellPrice = newSellPrice;
    emit sellPriceChanged();
}

int CaseCatPerks::morgagePrice() const
{
    return m_morgagePrice;
}

void CaseCatPerks::setmorgagePrice(int newMorgagePrice)
{
    if (m_morgagePrice == newMorgagePrice)
        return;
    m_morgagePrice = newMorgagePrice;
    emit morgagePriceChanged();
}
