#include "caserestarea.h"
#include <QDebug>
#include "../player.h"

CaseRestArea::CaseRestArea(QObject *parent)
    : Case("Unknown Rest Area", -1, parent)
{
    setType(CT_RestArea);
    int i = 0;
    while (m_prices.count() < RQ_COUNT)
    {
        m_prices.append(0);
    }
}

CaseRestArea::CaseRestArea(const QString &name, QVector<int> prices, FamilyType family, int position, QObject *parent)
    : Case(name, position, parent), m_prices(prices), m_family(family)
{
    setType(CT_RestArea);
    while (m_prices.count() < RQ_COUNT)
    {
        m_prices.append(0);
    }
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

Player *CaseRestArea::owner() const
{
    return m_owner;
}

void CaseRestArea::setOwner(Player *newOwner)
{
    m_owner = newOwner;
}

int CaseRestArea::get_price() const
{
    return m_prices.at(m_restQuality);
}

QVector<int> CaseRestArea::prices() const
{
    return m_prices;
}

void CaseRestArea::setPrices(const QVector<int> &newPrice)
{
    m_prices = newPrice;
}

void CaseRestArea::print_state()
{
    qDebug() << "Quality[" << m_restQuality << "] name[" << name() << "] price[" << m_prices <<"] family[" << m_family << "]";
}

void CaseRestArea::upgrade()
{
    if (canUpgrade() && m_owner && m_owner->canAfford(getUpgradeCost())) {
        m_owner->spendKibble(getUpgradeCost());
        
        // Increment the rest quality
        if (m_restQuality < RQ_HOTEL) {
            m_restQuality = static_cast<RestQuality>(static_cast<int>(m_restQuality) + 1);
            qDebug() << "Property upgraded to quality level " << m_restQuality;
        }
    }
}

int CaseRestArea::upgradeLevel() const
{
    return static_cast<int>(m_restQuality);
}

bool CaseRestArea::canUpgrade() const
{
    // Check if the property can be upgraded further
    return m_restQuality < RQ_HOTEL;
}

int CaseRestArea::getUpgradeCost() const
{
    // Calculate upgrade cost based on the current level
    return m_upgradeCost * (upgradeLevel() + 1);
}

void CaseRestArea::onLand(Player* player) {
    if (m_owner && m_owner != player) {
        int rentAmount = get_price();
        if (player->canAfford(rentAmount)) {
            player->spendKibble(rentAmount);
            m_owner->earnKibble(rentAmount);
            qDebug() << "Player paid rent of " << rentAmount;
        } else {
            qDebug() << "Player cannot afford rent.";
        }
    } else if (!m_owner) {
        // Logic to buy the rest area
        qDebug() << "Rest area is available for purchase.";
    }
}
