#ifndef CASEKIBBLEDISPENSER_H
#define CASEKIBBLEDISPENSER_H

#include "Case.h"
#include "player.h"

class CaseKibbleDispenser : public Case {
    Q_OBJECT
public:
    explicit CaseKibbleDispenser(QObject *parent = nullptr);
    CaseKibbleDispenser(const QString &name, int position, int reward = 200, QObject *parent = nullptr);

    int reward() const;
    void setReward(int newReward);

    void onLand(Player* player) override;

private:
    enum CaseType type = CT_KibbleDispenser;
    int m_reward = 200;
};

#endif // CASEKIBBLEDISPENSER_H 