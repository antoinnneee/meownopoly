#include "Case.h"
#include "../player.h"
#include <QDebug>
#include "game.h"

    Case::Case(QObject *parent)
    : QObject(parent), m_name("Unknown"),m_uniqueId(-42), type(Case::CS_Unknow) {}

    Case::Case(const QString &name, int uniqueId, QObject *parent)
        : QObject(parent), m_name(name),m_uniqueId(uniqueId), type(Case::CS_Unknow) {
        
    }

    Case::Case(const QString &json, QObject *parent)
        : QObject(parent)
    {
        QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
        QJsonObject obj = doc.object();
        m_name = obj["name"].toString();
        m_uniqueId = obj["uniqueId"].toInt();
        type = intToCaseType(obj["type"].toInt());

    }

int Case::uniqueId() const {
    return m_uniqueId;
}

void Case::setUniqueId(int newUniqueId)
{
    m_uniqueId = newUniqueId;
    emit uniqueIdChanged();
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
    json += "    \"uniqueId\": " + QString::number(uniqueId()) + ",\n";
    json += "    \"type\": " + QString::number(type) + ",\n";
    json += "    \"next\": [ ";
    for (int i = 0; i < next.size(); i++) {
        json += QString::number(next.at(i)->uniqueId()) + (i < next.size() - 1 ? ", " : "");
    }
    json += "],\n";
    json += "    \"prev\": [ ";
    for (int i = 0; i < prev.size(); i++) {
        json += QString::number(prev.at(i)->uniqueId()) + (i < prev.size() - 1 ? ", " : "");
    }
    json += "]\n";
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


// ---- CHAINED LIST MANIPULATION ----

Case *Case::getNext(int userSelectNext)
{
    if (!next.isEmpty() && next.at(userSelectNext))
        if (userSelectNext < next.size())
            return next.value(userSelectNext);
    return nullptr;
}

void Case::addNext(Case *newNext)
{
    next.append(newNext);
}

bool Case::removeNext(Case *caseToRemove)
{
    int index = next.indexOf(caseToRemove);
    if (index != -1) {
        next.removeAt(index);
        return true;
    }
    return false;
}

bool Case::removeNextAt(int index)
{
    if (index >= 0 && index < next.size()) {
        next.removeAt(index);
        return true;
    }
    return false;
}

Case *Case::getPrev(int userSelectPrev)
{
    if (prev.size() >= userSelectPrev)
        return prev.value(userSelectPrev);
    return nullptr;
}

void Case::addPrev(Case *newPrev)
{
    prev.append(newPrev);
}

bool Case::removePrev(Case *caseToRemove)
{
    int index = prev.indexOf(caseToRemove);
    if (index != -1) {
        prev.removeAt(index);
        return true;
    }
    return false;
}

bool Case::removePrevAt(int index)
{
    if (index >= 0 && index < prev.size()) {
        prev.removeAt(index);
        return true;
    }
    return false;
}
