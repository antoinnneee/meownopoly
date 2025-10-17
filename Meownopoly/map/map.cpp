#include "map.h"


#include <QJsonArray>
#include <QJsonObject>

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
