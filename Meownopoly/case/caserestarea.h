#ifndef CASERESTAREA_H
#define CASERESTAREA_H

#include <QObject>
#include "Case.h"


enum RestQuality{
    RQ_NONE,
    RQ_1STAR,
    RQ_2STAR,
    RQ_3STAR,
    RQ_4STAR,
    RQ_HOTEL,
    RQ_COUNT
};

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


class Player;
Q_DECLARE_OPAQUE_POINTER(Player*)

class CaseRestArea : public Case
{
    Q_OBJECT
    Q_PROPERTY(int restQuality READ restQuality NOTIFY restQualityChanged)
    Q_PROPERTY(int family READ family CONSTANT)
    Q_PROPERTY(Player* owner READ owner NOTIFY ownerChanged)
    Q_PROPERTY(int price READ get_price CONSTANT)
    Q_PROPERTY(QVector<int> prices READ prices CONSTANT)
    Q_PROPERTY(int upgradeLevel READ upgradeLevel NOTIFY upgradeLevelChanged)
    
public:
    explicit CaseRestArea(QObject *parent = nullptr);
    CaseRestArea(const QString &name, QVector<int> price, FamilyType family = FT_NONE, int position = -1, QObject *parent = nullptr);

    RestQuality restQuality() const;
    void setRestQuality(RestQuality newRestQuality);

    FamilyType family() const;
    void setFamily(FamilyType newFamily);

    Player *owner() const;
    void setOwner(Player *newOwner);

    int get_price() const;
    QVector<int> prices() const;
    void setPrices(const QVector<int> &newPrice);

    void print_state();

    void upgrade();
    int upgradeLevel() const;
    bool canUpgrade() const;
    int getUpgradeCost() const;

    void onLand(Player* player) override;
    
signals:
    void restQualityChanged();
    void ownerChanged();
    void upgradeLevelChanged();

private:
    enum CaseType type = CT_RestArea;
    enum RestQuality m_restQuality = RQ_NONE;   // Land level
    enum FamilyType m_family = FT_NONE;
    Player *m_owner = nullptr;
    QVector<int> m_prices;
    const int m_upgradeCost = 50; // Base cost to upgrade

};

#endif // CASERESTAREA_H
