#ifndef CASESTART_H
#define CASESTART_H

#include <QObject>
#include "Case.h"

class CaseStart : public Case
{
    Q_OBJECT
public:
    explicit CaseStart(QObject *parent = nullptr);

private:
    enum CaseType type = CT_KibbleDispenser;

};

#endif // CASESTART_H
