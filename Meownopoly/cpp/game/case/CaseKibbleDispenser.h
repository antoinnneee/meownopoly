#ifndef CASEKIBBLEDISPENSER_H
#define CASEKIBBLEDISPENSER_H

#include "Case.h"
#include "game/player.h"

class CaseKibbleDispenser : public Case {
    Q_OBJECT
    Q_PROPERTY(int reward READ reward WRITE setReward NOTIFY rewardChanged FINAL)
public:
    explicit CaseKibbleDispenser(QObject *parent = nullptr);
    CaseKibbleDispenser(const QString &name, int reward = 200, QObject *parent = nullptr);
    CaseKibbleDispenser(const QJsonObject &json, QObject *parent = nullptr);
    int reward() const;
    void setReward(int newReward);

    // void onLand(Player* player) override;

    QJsonObject toJsonObject() const override final;

signals:
    void rewardChanged();

private:
    enum CaseType type = CS_KibbleDispenser;
    int m_reward = 200;
};

#endif // CASEKIBBLEDISPENSER_H 
