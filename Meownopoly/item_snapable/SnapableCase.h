#ifndef SNAPABLECASE_H
#define SNAPABLECASE_H

#include <QObject>
#include "ItemSnapable.h"
#include "case/Case.h"


class SnapableCase : public ItemSnapable
{
    Q_OBJECT
public:
    SnapableCase();

private:

    Case *caseData;
};

#endif // SNAPABLECASE_H
