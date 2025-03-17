#ifndef CASEFREENAP_H
#define CASEFREENAP_H

#include "Case.h"
#include "player.h"

class CaseFreeNap : public Case {
    Q_OBJECT

public:
    explicit CaseFreeNap(QObject *parent = nullptr);
    CaseFreeNap(const QString &name, int position, QObject *parent = nullptr);

    int poolMoney() const;
    void setPoolMoney(int amount);
    void addToPool(int amount);

    void onLand(Player* player) override;

private:
    enum CaseType type = CT_FreeNap;
    int m_poolMoney = 0;
};

#endif // CASEFREENAP_H 