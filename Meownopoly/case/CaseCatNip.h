#ifndef CASECATNIP_H
#define CASECATNIP_H

#include "Case.h"
#include "player.h"

class CaseCatNip : public Case {
public:
    CaseCatNip(const QString &name, int position);

    void onLand(Player* player) override;
};

#endif // CASECATNIP_H 