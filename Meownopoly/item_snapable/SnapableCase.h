#ifndef SNAPABLECASE_H
#define SNAPABLECASE_H

#include <QObject>
#include "ItemSnapable.h"

class SnapableCase : public ItemSnapable
{
    Q_OBJECT
public:
    SnapableCase();

private:

    Case *caseCurrent;
};

#endif // SNAPABLECASE_H
