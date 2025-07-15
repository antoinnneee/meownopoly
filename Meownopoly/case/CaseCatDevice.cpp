#include "CaseCatDevice.h"
#include "../player.h"

CaseCatDevice::CaseCatDevice(QObject *parent)
    : CaseCatPerks("Unknown Rest Area", -1, parent)
{
    setType(CT_Device);
}

CaseCatDevice::CaseCatDevice(const QString &name, int position, QObject *parent)
    : CaseCatPerks(name, position, parent)
{
    setType(CT_Device);
}
bool CaseCatDevice::buyCase(Player *buyer) {
    if (CaseCatPerks::buyCase(buyer)){
        buyer->addCatDevice(this);
        return true;
    }
    return false;
}

bool CaseCatDevice::sellCase(Player *buyer)
{
    CaseCatPerks::sellCase(buyer);
    buyer->removeCatDevice(this);
    return true;
}


