#include "CaseCatDoor.h"
#include <QDebug>
#include "../player.h"

CaseCatDoor::CaseCatDoor(QObject *parent)
    : Case("Cat Door", -1, parent)
{
    setType(CT_CatDoor);
}

CaseCatDoor::CaseCatDoor(const QString &name, int position, int price, QObject *parent)
    : Case(name, position, parent)
{
    setType(CT_CatDoor);
    m_price = price;
}

int CaseCatDoor::rent() const
{
    return m_baseRent;
}

Player* CaseCatDoor::owner() const
{
    return m_owner;
}

void CaseCatDoor::setOwner(Player* newOwner)
{
    if (m_owner != newOwner) {
        m_owner = newOwner;
        emit ownerChanged();
    }
}

int CaseCatDoor::price() const
{
    return m_price;
}

void CaseCatDoor::setPrice(int newPrice)
{
    if (m_price != newPrice) {
        m_price = newPrice;
        emit priceChanged();
    }
}

void CaseCatDoor::onLand(Player* player)
{
    if (m_owner && m_owner != player) {
        // Calculate rent based on how many cat doors the owner has
        int rentAmount = m_baseRent;
        if (player->canAfford(rentAmount)) {
            player->spendKibble(rentAmount);
            m_owner->earnKibble(rentAmount);
            qDebug() << "Player paid rent of" << rentAmount << "for Cat Door";
        }
    } else if (!m_owner) {
        qDebug() << "Cat Door is available for purchase for" << m_price;
    }
} 
