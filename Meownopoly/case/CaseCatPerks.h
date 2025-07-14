#ifndef CASECATPERKS_H
#define CASECATPERKS_H

#include <QObject>

class Player;

class CaseCatPerks
{
    Q_OBJECT
public:
    CaseCatPerks();

    virtual bool buyCase(Player *buyer);
    virtual bool sellCase(Player *buyer, int price);


protected:

    int m_price = 0;
    int m_sell = 0;
    Player *owner;
};

#endif // CASECATPERKS_H
