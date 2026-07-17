#include "CaseCatDevice.h"
#include "game/player.h"

// CaseCatDevice::CaseCatDevice(QObject *parent)
//     : CaseCatPerks("Unknown Cat Device", -1, morgagePrice, parent)
// {
//     setType(CS_Device);
// }

CaseCatDevice::CaseCatDevice(CASECATPERKS_DEFAULT_PARAMETER_NOP, int taxe)
    : CASECATPERKS_DEFAULT_CONSTRUCS_PARAMETER, m_taxe(taxe)
{
    setType(Case::CS_Device);
}

CaseCatDevice::CaseCatDevice(const QJsonObject &json, QObject *parent)
    : CaseCatPerks(json, parent)
{
    setType(Case::CS_Device);

    m_taxe = json["taxe"].toInt();
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

QJsonObject CaseCatDevice::toJsonObject() const
{
    QJsonObject obj = CaseCatPerks::toJsonObject();
    obj["taxe"] = m_taxe;
    return obj;
}
