#ifndef CASECATPERKS_H
#define CASECATPERKS_H

#include <QObject>
#include "case/Case.h"

class Player;

class CaseCatPerks : public Case
{
    Q_OBJECT
    Q_PROPERTY(int price READ price WRITE setPrice NOTIFY priceChanged FINAL)
    Q_PROPERTY(int sellPrice READ sellPrice WRITE setsellPrice NOTIFY sellPriceChanged FINAL)

public:

    CaseCatPerks();


    virtual bool buyCase(Player *buyer);
    virtual bool sellCase(Player *buyer, int price);


    int price() const;
    void setPrice(int newPrice);

    int sellPrice() const;
    void setsellPrice(int newSellPrice);


signals:
    void priceChanged();

    void sellPriceChanged();

protected:

    Player *owner;
    int m_price;
    int m_sellPrice;
};

#endif // CASECATPERKS_H
