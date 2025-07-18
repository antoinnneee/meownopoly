#include "CaseStart.h"
#include <QDebug>

CaseStart::CaseStart(QObject *parent)
    : Case{parent}
{
    setType(Case::CS_KibbleDispenser);
}
