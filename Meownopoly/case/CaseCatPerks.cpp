#include "CaseCatPerks.h"
#include "../player.h"


CaseCatPerks::CaseCatPerks(const QString &name, int position, QObject *parent) :  Case::Case(name, position, parent){

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


int CaseCatPerks::moragePrice() const
{
    return m_moragePrice;
}

void CaseCatPerks::setMoragePrice(int newMoragePrice)
{
    if (m_moragePrice == newMoragePrice)
        return;
    m_moragePrice = newMoragePrice;
    emit moragePriceChanged();
}
