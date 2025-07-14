#ifndef CASECATDEVICE_H
#define CASECATDEVICE_H

#include <QObject>
#include "CaseCatPerks.h"

class Player;

class CaseCatDevice : public CaseCatPerks
{
    Q_OBJECT

public:

    explicit CaseCatDevice(QObject *parent = nullptr);
    CaseCatDevice(const QString &name, int position, QObject *parent = nullptr);

    Q_INVOKABLE bool buyCase(Player *buyer);
    Q_INVOKABLE bool sellCase(Player *buyer);


private :

};

#endif // CASECATDEVICE_H
