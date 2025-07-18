#ifndef CASECATPERKS_H
#define CASECATPERKS_H

#include <QObject>
#include "case/Case.h"

#define CASECATPERKS_DEFAULT_PARAMETER const QString &name, int position = -1, int morgagePrice = -1, int price = -1, int sellPrice = -1, QObject *parent = nullptr
#define CASECATPERKS_DEFAULT_PARAMETER_NOP const QString &name, int position, int morgagePrice, int price, int sellPrice, QObject *parent
#define CASECATPERKS_DEFAULT_CONSTRUCS_PARAMETER CaseCatPerks(name, position, price, sellPrice, morgagePrice, parent)


class Player;

class CaseCatPerks : public Case
{
    Q_OBJECT
    Q_PROPERTY(int price READ price WRITE setPrice NOTIFY priceChanged FINAL)
    Q_PROPERTY(int sellPrice READ sellPrice WRITE setsellPrice NOTIFY sellPriceChanged FINAL)
    Q_PROPERTY(int morgagePrice READ morgagePrice WRITE setmorgagePrice NOTIFY morgagePriceChanged FINAL)


public:

    CaseCatPerks(CASECATPERKS_DEFAULT_PARAMETER);


    bool buyCase(Player *buyer);
    void sellCase(Player *buyer);


    int price() const;
    void setPrice(int newPrice);

    int sellPrice() const;
    void setsellPrice(int newSellPrice);


    int morgagePrice() const;
    void setmorgagePrice(int newMorgagePrice);

signals:
    void priceChanged();

    void sellPriceChanged();

    void morgagePriceChanged();

protected:

    Player *owner;
    int m_price;
    int m_sellPrice;
    int m_morgagePrice;
};

#endif // CASECATPERKS_H
