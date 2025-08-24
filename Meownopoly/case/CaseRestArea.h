#ifndef CASERESTAREA_H
#define CASERESTAREA_H

#include <QObject>
#include "CaseCatPerks.h"

class Player;





class CaseRestArea : public CaseCatPerks
{
    Q_OBJECT
    Q_PROPERTY(RestQuality restQuality READ restQuality WRITE setRestQuality NOTIFY restQualityChanged)
    Q_PROPERTY(enum FamilyType family READ family WRITE setFamily  NOTIFY  familyChanged )
    
    Q_PROPERTY(int housePrice READ housePrice WRITE setHousePrice NOTIFY housePriceChanged FINAL)
    Q_PROPERTY(int hotelPrice READ hotelPrice WRITE setHotelPrice NOTIFY hotelPriceChanged FINAL)
    Q_PROPERTY(QList<int> rentPrice READ rentPrice WRITE setRentPrice NOTIFY rentPriceChanged FINAL)


public:
    explicit CaseRestArea(QObject *parent = nullptr);

    enum RestQuality{
        RQ_NONE,
        RQ_1STAR,
        RQ_2STAR,
        RQ_3STAR,
        RQ_4STAR,
        RQ_HOTEL,
        RQ_COUNT
    };
    Q_ENUM(RestQuality)

    enum FamilyType {
        FT_NONE,
        FT_BROWN,
        FT_LIGHTBLUE,
        FT_PINK,
        FT_ORANGE,
        FT_RED,
        FT_YELLOW,
        FT_GREEN,
        FT_DARKBLUE,
        FT_COUNT
    };
    Q_ENUM(FamilyType)
    // CaseRestArea(const QString &name, int price= -1, int sellPrice = -1,int position = -1,  FamilyType family = FT_NONE, int housePrice = -1, int hotelPrice = -1, QList<int> rentPrice = QList<int>(), QObject *parent = nullptr);
    CaseRestArea(CASECATPERKS_DEFAULT_PARAMETER,  FamilyType family = FT_NONE, int housePrice = -1, int hotelPrice = -1, QList<int> rentPrice = QList<int>());
    CaseRestArea(const QString &json, QObject *parent = nullptr);

    
    CaseRestArea::RestQuality restQuality() const;
    void setRestQuality(CaseRestArea::RestQuality newRestQuality);

    FamilyType family() const;
    void setFamily(CaseRestArea::FamilyType newFamily);


    // void print_state();

    bool canUpgrade() const;

    Q_INVOKABLE bool buyCase(Player *buyer);
    Q_INVOKABLE bool sellCase(Player *buyer);


    int housePrice() const;
    void setHousePrice(int newHousePrice);

    int hotelPrice() const;
    void setHotelPrice(int newHotelPrice);

    QList<int> rentPrice() const;
    void setRentPrice(const QList<int> &newRentPrice);

    Q_INVOKABLE virtual QString toJSON() override;

signals:
    void restQualityChanged();
    void  familyChanged();


    void housePriceChanged();

    void hotelPriceChanged();

    void rentPriceChanged();

private:
    enum CaseType type = CS_RestArea;
    enum RestQuality m_restQuality = RQ_NONE;   // Land level
    enum FamilyType m_family = FT_NONE;
    int m_housePrice;
    int m_hotelPrice;
    QList<int> m_rentPrice;
};

#endif // CASERESTAREA_H
