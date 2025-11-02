#ifndef CASEFACTORY_H
#define CASEFACTORY_H

#include "case/Case.h"

class CaseFactory : public Case
{
public:
    CaseFactory();
    static void registerCaseQml();
    static Case* createCase(CaseType type);
    static Case* createCase(const QJsonObject &caseJson);
};

#endif // CASEFACTORY_H
