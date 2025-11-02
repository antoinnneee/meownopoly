#include "CaseCatPerks.h"
#include "game/player.h"
#include <QString>


// CaseCatPerks::CaseCatPerks(const QString &name, int position, int price, int sellPrice, int morgagePrice, QObject *parent) :  Case::Case(name, position, parent), m_morgagePrice(morgagePrice){

// }

CaseCatPerks::CaseCatPerks(const QString &name, int morgagePrice, int price, int sellPrice, QObject *parent) :
    Case(name), m_morgagePrice(morgagePrice), m_price(price) ,m_sellPrice(sellPrice) {
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

Player *CaseCatPerks::owner() const
{
    return m_owner;
}

void CaseCatPerks::setOwner(Player *newOwner)
{
    if (m_owner == newOwner)
        return;
    m_owner = newOwner;
    emit ownerChanged();
}


QString CaseCatPerks::toJSON()
{
    QString json;
    json = Case::toJSON();
    json.removeLast();
    json.removeLast();
    json+= ",\n";
    json += "    \"price\": " + QString::number(price()) + ",\n";
    json += "    \"sellPrice\": " + QString::number(sellPrice()) + ",\n";
    json += "    \"morgagePrice\": " + QString::number(morgagePrice()) + "\n";
    json += "}";
    return json;
}

CaseCatPerks::CaseCatPerks(const QJsonObject &json, QObject *parent)
    : Case(json, parent)
{
    m_price = json["price"].toInt();
    m_sellPrice = json["sellPrice"].toInt();
    m_morgagePrice = json["morgagePrice"].toInt();
}
