#include "Case.h"
#include "../player.h"
#include <QDebug>
#include "game.h"

Case::Case(QObject *parent)
    : QObject(parent), m_name("Unknown"), type(Case::CS_Unknow) {
}

Case::Case(const QString &name, QObject *parent)
    : QObject(parent), m_name(name), type(Case::CS_Unknow) {
}

Case::Case(const QJsonObject &json, QObject *parent)
    : QObject(parent)
{

    m_name = json["name"].toString();
    type = intToCaseType(json["type"].toInt());

}


Case::CaseType Case::getType() const
{
    return type;
}

void Case::setType(CaseType newType)
{
    qDebug()<<"void Case::setType(CaseType newType)";
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
    if (player) {
        addPlayer(player);
        qDebug() << "Player" << player->name() << "landed on " << name();
        // Add any default landing behavior here
    }
}

void Case::onLeave(Player* player)
{
    if (player) {
        removePlayer(player);
        qDebug() << "Player" << player->name() << "left " << name();
    }
}

void Case::onHover(Player* player)
{
    if (player) {
        qDebug() << "Player" << player->name() << "hovered over " << name();
    }
}

QString Case::toJSON()
{
    QString json;
    json += "{\n";
    json += "    \"name\": \"" + name() + "\",\n";
    json += "    \"type\": " + QString::number(type) + ",\n";
    json += "}";
    return json;
}

void Case::addPlayer(Player *player)
{
    if (!listPlayer.contains(player)){
        listPlayer.append(player);
    }
    return;
}

void Case::removePlayer(Player *player)
{
    if (listPlayer.contains(player)){
        listPlayer.remove(listPlayer.indexOf(player), 1);
    }
    return;
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

