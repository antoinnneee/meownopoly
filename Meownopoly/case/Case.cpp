#include "Case.h"
#include "../player.h"
#include <QDebug>

    Case::Case(QObject *parent)
    : QObject(parent), m_name("Unknown"), m_position(-1), type(Case::CS_Unknow) {}

    Case::Case(const QString &name, int position, QObject *parent)
    : QObject(parent), m_name(name), m_position(position), type(Case::CS_Unknow) {}

int Case::position() const {
    return m_position;
}

void Case::setPosition(int newPosition)
{
    m_position = newPosition;
    emit positionChanged();
}

Case::CaseType Case::getType() const
{
    return type;
}

void Case::setType(CaseType newType)
{
    type = newType;
    emit typeChanged();
}

QString Case::name() const
{
    return m_name;
}

void Case::setName(const QString &newName)
{
    m_name = newName;
    emit nameChanged();
}

void Case::onLand(Player* player)
{
    // Default implementation - can be overridden by derived classes
    Q_UNUSED(player);
}

void Case::onLeave(Player* player)
{
    // Default implementation - can be overridden by derived classes
    Q_UNUSED(player);
}

void Case::onHover(Player* player)
{
    // Default implementation - can be overridden by derived classes
    Q_UNUSED(player);
}

Case::CaseType Case::intToCaseType(int type)
{
    switch (type) {
        case 0: return CS_KibbleDispenser;  // Start (Départ)
        case 1: return CS_RestArea;         // Property (Terrain)
        case 2: return CS_CardBoardBox;     // Community Chest (Caisse de Communauté)
        case 3: return CS_CatNip;           // Chance
        case 4: return CS_Jail;             // Jail (Prison)
        case 5: return CS_ToJail;           // Go to Jail (Allez en Prison)
        case 6: return CS_CatDoor;          // Railroad (Gare)
        case 7: return CS_FreeNap;          // Free Parking (Parc Gratuit)
        case 8: return CS_Device;           // Utility (Service/Compagnie)
        case 9: return CS_Taxe;             // Tax (Taxe)
        default: return CS_Unknow;          // Unknown type
    }
}
