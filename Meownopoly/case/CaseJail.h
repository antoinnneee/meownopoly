#ifndef CASEJAIL_H
#define CASEJAIL_H

#include "Case.h"
#include "player.h"
#include <QMap>

class CaseJail : public Case {
public:
    CaseJail(const QString &name, int position, int jailFine);

    void onLand(Player* player) override;
    void sendToJail(Player* player);
    bool isPlayerInJail(Player* player) const;
    void releasePlayer(Player* player);

private:
    QMap<Player*, int> m_playersInJail; // Map to track players and their turns in jail
    const int m_maxJailTurns = 3; // Maximum turns a player can stay in jail
    int m_jailFine; // Fine to get out of jail
};

#endif // CASEJAIL_H 