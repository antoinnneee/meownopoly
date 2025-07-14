#ifndef CASERESTAREA_H
#define CASERESTAREA_H

#include <QObject>
#include "CaseCatPerks.h"

class Player;

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


Q_DECLARE_OPAQUE_POINTER(Player*)

class CaseRestArea : public CaseCatPerks
{
    Q_OBJECT
    Q_PROPERTY(int restQuality READ restQuality NOTIFY restQualityChanged)
    Q_PROPERTY(int family READ family CONSTANT)
    
public:
    explicit CaseRestArea(QObject *parent = nullptr);
    CaseRestArea(const QString &name, FamilyType family = FT_NONE, int position = -1, QObject *parent = nullptr);

    RestQuality restQuality() const;
    void setRestQuality(RestQuality newRestQuality);

    FamilyType family() const;
    void setFamily(FamilyType newFamily);

    Player *owner() const;
    void setOwner(Player *newOwner);

    // void print_state();

    void onLand(Player* player) override;
    bool canUpgrade() const;

    Q_INVOKABLE bool buyCase(Player *buyer);
    Q_INVOKABLE bool sellCase(Player *buyer);


signals:
    void restQualityChanged();
    void ownerChanged();


private:
    enum CaseType type = CT_RestArea;
    enum RestQuality m_restQuality = RQ_NONE;   // Land level
    enum FamilyType m_family = FT_NONE;
};

#endif // CASERESTAREA_H
