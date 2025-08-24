#ifndef CASECATDEVICE_H
#define CASECATDEVICE_H

#include <QObject>
#include "CaseCatPerks.h"

class Player;

class CaseCatDevice : public CaseCatPerks
{
    Q_OBJECT
    Q_PROPERTY(int taxe READ taxe WRITE setTaxe NOTIFY taxeChanged FINAL)

public:
    CaseCatDevice(CASECATPERKS_DEFAULT_PARAMETER, int taxe = -1);

    Q_INVOKABLE bool buyCase(Player *buyer);
    Q_INVOKABLE bool sellCase(Player *buyer);


    int taxe() const;
    void setTaxe(int newTaxe);

    Q_INVOKABLE virtual QString toJSON() override;

signals:
    void taxeChanged();

private :

    int m_taxe;
};

#endif // CASECATDEVICE_H
