#ifndef CASECATPERKS_H
#define CASECATPERKS_H

#include <QObject>
#include <QUuid>
#include "case/Case.h"

#define CASECATPERKS_DEFAULT_PARAMETER const QString &name, QUuid id = QUuid::createUuid(), int morgagePrice = -1, int price = -1, int sellPrice = -1, QObject *parent = nullptr
#define CASECATPERKS_DEFAULT_PARAMETER_NOP const QString &name, QUuid id, int morgagePrice, int price, int sellPrice, QObject *parent
#define CASECATPERKS_DEFAULT_CONSTRUCS_PARAMETER CaseCatPerks(name, id, price, sellPrice, morgagePrice, parent)


class CaseCatPerks : public Case
{
    Q_OBJECT
    Q_PROPERTY(int price READ price WRITE setPrice NOTIFY priceChanged FINAL)
    Q_PROPERTY(int sellPrice READ sellPrice WRITE setsellPrice NOTIFY sellPriceChanged FINAL)
    Q_PROPERTY(int morgagePrice READ morgagePrice WRITE setmorgagePrice NOTIFY morgagePriceChanged FINAL)
    Q_PROPERTY(Player* owner READ owner NOTIFY ownerChanged);
public:

    CaseCatPerks(CASECATPERKS_DEFAULT_PARAMETER);
    CaseCatPerks(const QJsonObject &json, QObject *parent = nullptr);


    bool buyCase(Player *buyer);
    void sellCase(Player *buyer);


    int price() const;
    void setPrice(int newPrice);

    int sellPrice() const;
    void setsellPrice(int newSellPrice);


    int morgagePrice() const;
    void setmorgagePrice(int newMorgagePrice);

    Player *owner() const;
    Q_INVOKABLE void setOwner(Player *newOwner);
    Q_INVOKABLE virtual QString toJSON() override;


signals:
    void priceChanged();

    void sellPriceChanged();

    void morgagePriceChanged();

    void ownerChanged();

protected:

    Player *m_owner = nullptr;
    int m_morgagePrice;
    int m_price;
    int m_sellPrice;
};

#endif // CASECATPERKS_H
