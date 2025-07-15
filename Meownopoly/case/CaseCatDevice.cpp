#include "CaseCatDevice.h"
#include "../player.h"

// CaseCatDevice::CaseCatDevice(QObject *parent)
//     : CaseCatPerks("Unknown Cat Device", -1, morgagePrice, parent)
// {
//     setType(CT_Device);
// }

CaseCatDevice::CaseCatDevice(CASECATPERKS_DEFAULT_PARAMETER_NOP, int taxe)
    : CASECATPERKS_DEFAULT_CONSTRUCT_PARAMETER, m_taxe(taxe)
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



int CaseCatDevice::taxe() const
{
    return m_taxe;
}

void CaseCatDevice::setTaxe(int newTaxe)
{
    if (m_taxe == newTaxe)
        return;
    m_taxe = newTaxe;
    emit taxeChanged();
}
