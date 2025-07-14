#ifndef CASECATDEVICE_H
#define CASECATDEVICE_H

#include <QObject>
#include "case/Case.h"

class Player;

class CaseCatDevice : public Case
{
    Q_OBJECT
public:
    CaseCatDevice();

    void buy(Player *player);

private :



};

#endif // CASECATDEVICE_H
