#include "CaseCatDoor.h"
#include <QDebug>
#include "../player.h"

CaseCatDoor::CaseCatDoor(const QString &name, int position, int baseRent)
    : Case(name, position), m_baseRent(baseRent) {}

int CaseCatDoor::rent() const {
    // Rent calculation can be based on the number of CatDoors owned
    return m_baseRent; // Simplified for now
}

Player* CaseCatDoor::owner() const {
    return m_owner;
}

void CaseCatDoor::setOwner(Player* newOwner) {
    m_owner = newOwner;
}

void CaseCatDoor::onLand(Player* player) {
    if (m_owner && m_owner != player) {
        int rentAmount = rent();
        if (player->canAfford(rentAmount)) {
            player->spendKibble(rentAmount);
            m_owner->earnKibble(rentAmount);
            qDebug() << "Player paid rent of " << rentAmount;
        } else {
            qDebug() << "Player cannot afford rent.";
        }
    } else if (!m_owner) {
        // Logic to buy the CatDoor
        qDebug() << "CatDoor is available for purchase.";
    }
} 