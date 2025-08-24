#ifndef CASECATDOOR_H
#define CASECATDOOR_H

#include "CaseCatPerks.h"

class CaseCatDoor : public CaseCatPerks {

    Q_OBJECT
    Q_PROPERTY(int indexCatDoor READ indexCatDoor WRITE setIndexCatDoor NOTIFY indexCatDoorChanged FINAL)
    Q_PROPERTY(int travelPrice READ travelPrice WRITE setTravelPrice NOTIFY travelPriceChanged FINAL)

public:
    CaseCatDoor(CASECATPERKS_DEFAULT_PARAMETER);
    CaseCatDoor(const QString &json, QObject *parent = nullptr);
    ~CaseCatDoor() override = default;

    Q_INVOKABLE bool buyCase(Player *buyer);
    Q_INVOKABLE bool sellCase(Player *buyer);


    // void onLand(Player* player) override;


    int indexCatDoor() const;
    void setIndexCatDoor(int newIndexCatDoor);

    int travelPrice() const;
    void setTravelPrice(int newTravelPrice);

    Q_INVOKABLE virtual QString toJSON() override;

signals:
    void indexCatDoorChanged();

    void travelPriceChanged();

private:


    int m_indexCatDoor;
    int m_travelPrice;
};

#endif // CASECATDOOR_H
