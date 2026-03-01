#include "map.h"
#include "mapfilemanager.h"
#include "maptypes.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

Map::Map(QObject *parent) : QObject(parent)
{
}

Map::Map(QJsonObject jsonObject, QObject *parent) : QObject(parent)
{
    QJsonArray snapableTilesArray = jsonObject["snapableTiles"].toArray();
    // qDebug() << "Snapable tiles:" << snapableTilesArray.size();
    // qDebug() << "--------------------------------";
    // qDebug() << "Start loading snapable tiles";

    for (const QJsonValueRef value : snapableTilesArray) {
        const QJsonObject tileObject = value.toObject();
        ItemSnapable *is = new ItemSnapable(tileObject);
        m_tiles.append(is);
    }
    updateTileCounts();

    // qDebug() << "Snapable tiles loaded successfully";
    // qDebug() << "--------------------------------";
    // qDebug() << "building links between snapable tiles";

    for (ItemSnapable *is : std::as_const(m_tiles)) {
        QJsonObject originalJson = is->getOriginalJson();
        QJsonArray nextIdArray = originalJson["next"].toArray();

        for (const QJsonValueRef value : nextIdArray) {
            QString nextId = value.toString();
            for (ItemSnapable *targetTile : m_tiles) {
                if (targetTile->uniqueId().toString() == nextId) {
                    is->addNext(targetTile);
                    targetTile->addPrev(is);
                    // qDebug() << "Link built between" << is->uniqueId() << "and" << targetTile->uniqueId();
                }
            }
        }
    }
    // qDebug() << "Links built successfully";

    // qDebug() << "--------------------------------";

}


MapInfo *Map::getMapInfo() const
{
    return mapInfo;
}

void Map::setMapInfo(MapInfo *newMapInfo)
{
    if (mapInfo == newMapInfo)
        return;
    mapInfo = newMapInfo;
    emit mapInfoChanged();
}

QList<ItemSnapable *> Map::tiles() const
{
    return m_tiles;
}

void Map::setTiles(const QList<ItemSnapable *> &newTiles)
{
    m_tiles = newTiles;
    updateTileCounts();
}

void Map::updateTileCounts()
{
    int caseCount = 0;
    int decorationCount = 0;
    int zoneCount = 0;
    for (ItemSnapable *tile : std::as_const(m_tiles)) {
        switch (tile->tileType()) {
        case ItemSnapable::CaseTile:
            ++caseCount;
            break;
        case ItemSnapable::DecorationTile:
            ++decorationCount;
            break;
        case ItemSnapable::PhysicZoneTile:
            ++zoneCount;
            break;
        default:
            break;
        }
    }
    if (m_caseTileCount != caseCount) {
        m_caseTileCount = caseCount;
        emit caseTileCountChanged();
    }
    if (m_decorationTileCount != decorationCount) {
        m_decorationTileCount = decorationCount;
        emit decorationTileCountChanged();
    }
    if (m_zoneTileCount != zoneCount) {
        m_zoneTileCount = zoneCount;
        emit zoneTileCountChanged();
    }
}

Map *Map::loadMap(QJsonObject newEdit)
{
    QJsonObject jsonObject = newEdit;
    Map *map = new Map(jsonObject);

    // Créer MapInfo depuis JSON
    QJsonObject mapInfoObject = jsonObject["mapInfo"].toObject();
    MapInfo *mapInfo = new MapInfo(mapInfoObject);
    map->setMapInfo(mapInfo);
    return map;
}

Map *Map::loadMap(QString mapName, MapTypes::MapType mapType)
{
    QJsonObject jsonObject;
    switch (mapType){
    case MapTypes::AUTOSAVE:
    case MapTypes::CUSTOM:
        jsonObject = MapFileManager::readMapFile(mapName, mapType);
        if (jsonObject.isEmpty()) {
            qDebug() << "Failed to read map file:" << mapName;
            return nullptr;
        }
        break;
    case MapTypes::UNDOREDO:
        qWarning() << Q_FUNC_INFO << "  - SHOULD NOT BEEN SEEN WITH UNDOREDO TYPE";
        break;
    default:
        break;
    }

    Map *map = new Map(jsonObject);

    // Créer MapInfo depuis JSON
    QJsonObject mapInfoObject = jsonObject["mapInfo"].toObject();
    MapInfo *mapInfo = new MapInfo(mapInfoObject);
    map->setMapInfo(mapInfo);
    return map;
}
