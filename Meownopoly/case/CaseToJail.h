#ifndef CASETOJAIL_H
#define CASETOJAIL_H

#include "Case.h"
#include "player.h"
#include "CaseJail.h"

class CaseToJail : public Case {
    Q_OBJECT
public:
    explicit CaseToJail(QObject *parent = nullptr);
    CaseToJail(const QString &name, int uniqueId, QObject *parent = nullptr);

    // void onLand(Player* player) override;
    void setJailCase(CaseJail* jailCase);
    Q_INVOKABLE virtual QString getJSON();

private:
    CaseJail* m_jailCase = nullptr;
    enum CaseType type = CS_ToJail;
};

#endif // CASETOJAIL_H 
