#ifndef CASECATDOOR_H
#define CASECATDOOR_H

#include "Case.h"
#include "player.h"

class CaseCatDoor : public Case {
public:
    CaseCatDoor(const QString &name, int position, int baseRent);

    int rent() const;
    Player* owner() const;
    void setOwner(Player* newOwner);

    void onLand(Player* player) override;

private:
    Player* m_owner = nullptr;
    int m_baseRent;
};

#endif // CASECATDOOR_H 