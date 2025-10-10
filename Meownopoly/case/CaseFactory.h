#ifndef CASEFACTORY_H
#define CASEFACTORY_H

#include "case/CaseRestArea.h"
#include "case/CaseCardBoardBox.h"
#include "case/CaseCatNip.h"
#include "case/CaseJail.h"
#include "case/CaseToJail.h"
#include "case/CaseCatDoor.h"
#include "case/CaseFreeNap.h"
#include "case/CaseCatDevice.h"

class CaseFactory : public Case
{
public:
    CaseFactory();
};

#endif // CASEFACTORY_H
