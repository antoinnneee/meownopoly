#ifndef CASECATDOOR_H
#define CASECATDOOR_H

#include "Case.h"
#include "player.h"

class CaseCatDoor : public Case {
    Q_OBJECT
    Q_PROPERTY(Player* owner READ owner WRITE setOwner NOTIFY ownerChanged)
    Q_PROPERTY(int price READ price WRITE setPrice NOTIFY priceChanged)
    Q_PROPERTY(int rent READ rent CONSTANT)

public:
    explicit CaseCatDoor(QObject *parent = nullptr);
    CaseCatDoor(const QString &name, int position, int price = 200, QObject *parent = nullptr);
    ~CaseCatDoor() override = default;

    int rent() const;
    Player* owner() const;
    void setOwner(Player* newOwner);
    int price() const;
    void setPrice(int newPrice);
    void onLand(Player* player) override;

signals:
    void ownerChanged();
    void priceChanged();

private:
    Player* m_owner = nullptr;
    int m_baseRent = 25;
    int m_price = 200;
};

#endif // CASECATDOOR_H
