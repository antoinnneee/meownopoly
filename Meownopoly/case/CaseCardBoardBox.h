#ifndef CASECARDBOARDBOX_H
#define CASECARDBOARDBOX_H

#include "Case.h"
#include "player.h"

class CaseCardBoardBox : public Case {
public:
    CaseCardBoardBox(const QString &name, int position);

    void onLand(Player* player) override;
};

#endif // CASECARDBOARDBOX_H 