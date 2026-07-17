#ifndef CASETOJAIL_H
#define CASETOJAIL_H

#include "Case.h"
#include "CaseJail.h"

class CaseToJail : public Case {
    Q_OBJECT
public:
    explicit CaseToJail(QObject *parent = nullptr);
    CaseToJail(const QString &name, QObject *parent = nullptr);
    CaseToJail(const QJsonObject &json, QObject *parent = nullptr);

    // void onLand(Player* player) override;
    void setJailCase(CaseJail* jailCase);
    // Pas de champs propres : toJsonObject()/toJSON() de Case suffisent.

private:
    CaseJail* m_jailCase = nullptr;
    enum CaseType type = CS_ToJail;
};

#endif // CASETOJAIL_H 
