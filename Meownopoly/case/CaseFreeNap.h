#ifndef CASEFREENAP_H
#define CASEFREENAP_H

#include "Case.h"
#include "player.h"

class CaseFreeNap : public Case {
    Q_OBJECT
public:
    explicit CaseFreeNap(QObject *parent = nullptr);
    CaseFreeNap(const QString &name, int position, QObject *parent = nullptr);

    void onLand(Player* player) override;
    
    int pot() const;
    void setPot(int newPot);
    void addToPot(int amount);

private:
    int m_pot = 0; // Accumulated money in the pot
    enum CaseType type = CT_FreeNap;
};

#endif // CASEFREENAP_H 