#include "CaseCatPerks.h"

CaseCatPerks::CaseCatPerks() {}

bool CaseCatPerks::buyCase(Player *buyer)
{

}

bool CaseCatPerks::sellCase(Player *buyer, int price)
{

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

bool CaseCatPerks::checkKibble(Player *player)
{
    return (price < player->kibble());
}
