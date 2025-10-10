#ifndef CASEJAIL_H
#define CASEJAIL_H

#include "Case.h"
#include "player.h"
#include <QMap>

class CaseJail : public Case {
    Q_OBJECT
public:
    CaseJail(const QString &name, QUuid uniqueId, int jailFine = -1);
    CaseJail(const QJsonObject &json, QObject *parent = nullptr);
    // void onLand(Player* player) override;
    void sendToJail(Player* player);
    bool isPlayerInJail(Player* player) const;
    void releasePlayer(Player* player);

    Q_INVOKABLE QString toJSON() override final;

private:
    QMap<Player*, int> m_playersInJail; // Map to track players and their turns in jail
    const int m_maxJailTurns = 3; // Maximum turns a player can stay in jail
    int m_jailFine; // Fine to get out of jail
};

#endif // CASEJAIL_H 
