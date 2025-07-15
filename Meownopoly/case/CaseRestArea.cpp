#include "CaseRestArea.h"
#include <QDebug>
#include "../player.h"


CaseRestArea::CaseRestArea(QObject *parent)
    : CaseCatPerks("Unknown Rest Area", -1, parent)
{
    setType(CT_RestArea);
}

CaseRestArea::CaseRestArea(const QString &name, FamilyType family, int position, QObject *parent)
    : CaseCatPerks(name, position, parent), m_family(family)
{
    setType(CT_RestArea);
}

RestQuality CaseRestArea::restQuality() const
{
    return m_restQuality;
}

void CaseRestArea::setRestQuality(RestQuality newRestQuality)
{
    m_restQuality = newRestQuality;
}

FamilyType CaseRestArea::family() const
{
    return m_family;
}

void CaseRestArea::setFamily(FamilyType newFamily)
{
    m_family = newFamily;
}



// void CaseRestArea::print_state()
// {
//     qDebug() << "Quality[" << m_restQuality << "] name[" << name() << "] price[" << m_prices <<"] family[" << m_family << "]";
// }



bool CaseRestArea::buyCase(Player *buyer) {
    if (CaseCatPerks::buyCase(buyer)){
        buyer->addProperty(this);
        return true;
    }
    return false;
}

bool CaseRestArea::sellCase(Player *buyer)
{
    CaseCatPerks::sellCase(buyer);
    buyer->removeProperty(this);
    return true;
}

int CaseRestArea::name() const
{
    return m_rank;
}

void CaseRestArea::setName(int newRank)
{
    if (m_rank == newRank)
        return;
    m_rank = newRank;
    emit nameChanged();
}
