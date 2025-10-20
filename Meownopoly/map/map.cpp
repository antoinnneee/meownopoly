#include "map.h"
#include "map/mapfilemanager.h"
#include "map/maptypes.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QDebug>

Map::Map(QObject *parent) : QObject(parent)
{
}

Map::Map(QJsonObject jsonObject, QObject *parent) : QObject(parent)
{
    QJsonArray snapableTilesArray = jsonObject["snapableTiles"].toArray();
    qDebug() << "Snapable tiles:" << snapableTilesArray.size();
    qDebug() << "--------------------------------";
    qDebug() << "Start loading snapable tiles";

    for (const QJsonValueRef value : snapableTilesArray) {
        const QJsonObject tileObject = value.toObject();
        ItemSnapable *is = new ItemSnapable(tileObject);
        m_tiles.append(is);
        /*
        if (is->tileType() == TileType::CaseTile){
            m_caseTiles.append(is);
        }
        if (is->tileType() == TileType::DecorationTile){
            m_decorationTiles.append(is);
        }
*/
    }

    qDebug() << "Snapable tiles loaded successfully";
    qDebug() << "--------------------------------";
    qDebug() << "building links between snapable tiles";

    for (ItemSnapable *is : std::as_const(m_tiles)) {
        QJsonObject originalJson = is->getOriginalJson();
        QJsonArray nextIdArray = originalJson["next"].toArray();

        for (const QJsonValueRef value : nextIdArray) {
            QString nextId = value.toString();
            for (ItemSnapable *targetTile : m_tiles) {
                if (targetTile->uniqueId().toString() == nextId) {
                   is->addNext(targetTile);
                    targetTile->addPrev(is);
                    qDebug() << "Link built between" << is->uniqueId() << "and" << targetTile->uniqueId();
                }
            }
        }
    }
    qDebug() << "Links built successfully";

    qDebug() << "--------------------------------";

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
}

Map *Map::loadFromFile(const QString &mapName, MapTypes::MapType mapType)
{
    QJsonObject jsonObject = MapFileManager::readMapFile(mapName, mapType);
    
    if (jsonObject.isEmpty()) {
        qDebug() << "Failed to read map file:" << mapName;
        return nullptr;
    }
    
    Map *map = new Map(jsonObject);
    
    // CrÃ©er MapInfo depuis JSON
    QJsonObject mapInfoObject = jsonObject["mapInfo"].toObject();
    MapInfo *mapInfo = new MapInfo(mapInfoObject);
    map->setMapInfo(mapInfo);
    
    // Ã‰mettre signaux pour chaque tuile
    for (ItemSnapable *tile : map->m_tiles) {
        emit map->foundItemSnapableTile(tile);
    }
    
    // Ã‰mettre signal de chargement terminÃ©
    emit map->mapLoaded(map);
    
    return map;
}
