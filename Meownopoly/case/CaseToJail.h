#ifndef CASETOJAIL_H
#define CASETOJAIL_H

#include "Case.h"
#include "player.h"
#include "CaseJail.h"

class CaseToJail : public Case {
    Q_OBJECT
public:
    explicit CaseToJail(QObject *parent = nullptr);
    CaseToJail(const QString &name, int position, QObject *parent = nullptr);

    void onLand(Player* player) override;
    void setJailCase(CaseJail* jailCase);

private:
    CaseJail* m_jailCase = nullptr;
    enum CaseType type = CT_ToJail;
};

#endif // CASETOJAIL_H 