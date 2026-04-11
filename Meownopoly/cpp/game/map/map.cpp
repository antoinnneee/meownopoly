#include "map.h"
#include "mapfilemanager.h"
#include "maptypes.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QHash>
#include <QDebug>

Map::Map(QObject *parent) : QObject(parent)
{
}

Map::Map(QJsonObject jsonObject, QObject *parent) : QObject(parent)
{
    if (!jsonObject.contains("snapableTiles") || !jsonObject["snapableTiles"].isArray()) {
        qWarning() << "MAP_LOADING: Clé 'snapableTiles' manquante ou invalide dans le JSON de la map";
        return;
    }

    QJsonArray snapableTilesArray = jsonObject["snapableTiles"].toArray();

    for (int i = 0; i < snapableTilesArray.size(); ++i) {
        if (!snapableTilesArray[i].isObject()) {
            qWarning() << "MAP_LOADING: Entrée snapableTiles[" << i << "] n'est pas un objet JSON - ignorée";
            continue;
        }
        const QJsonObject tileObject = snapableTilesArray[i].toObject();

        // Vérifier les champs obligatoires avant de créer la tile
        if (!tileObject.contains("uniqueId") || !tileObject.contains("tileType")) {
            qWarning() << "MAP_LOADING: Tile[" << i << "] sans uniqueId ou tileType - ignorée";
            continue;
        }

        ItemSnapable *is = new ItemSnapable(tileObject);
        QQmlEngine::setObjectOwnership(is, QQmlEngine::JavaScriptOwnership);
        m_tiles.append(is);
    }
    updateTileCounts();

    // qDebug() << "Snapable tiles loaded successfully";
    // qDebug() << "--------------------------------";
    // qDebug() << "building links between snapable tiles";

    // Construire un index UUID → tile pour une résolution O(1)
    QHash<QString, ItemSnapable*> tileIndex;
    for (ItemSnapable *tile : std::as_const(m_tiles)) {
        QString id = tile->uniqueId().toString();
        if (tileIndex.contains(id)) {
            qWarning() << "MAP_LOADING: UUID dupliqué détecté:" << id << "- seule la dernière tile sera référencée";
        }
        tileIndex[id] = tile;
    }

    // Reconstruire les connexions avec validation des références
    for (ItemSnapable *is : std::as_const(m_tiles)) {
        QJsonObject originalJson = is->getOriginalJson();
        QJsonArray nextIdArray = originalJson["next"].toArray();

        for (const QJsonValueRef value : nextIdArray) {
            QString nextId = value.toString();
            if (nextId.isEmpty()) {
                qWarning() << "MAP_LOADING: UUID vide dans next[] de la tile" << is->uniqueId().toString();
                continue;
            }
            ItemSnapable *targetTile = tileIndex.value(nextId, nullptr);
            if (targetTile) {
                is->addNext(targetTile);
                targetTile->addPrev(is);
            } else {
                qWarning() << "MAP_LOADING: Référence next invalide:" << nextId
                           << "depuis la tile" << is->uniqueId().toString()
                           << "- connexion ignorée";
            }
        }
    }

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

    // Créer MapInfo depuis JSON (avec vérification)
    if (jsonObject.contains("mapInfo") && jsonObject["mapInfo"].isObject()) {
        QJsonObject mapInfoObject = jsonObject["mapInfo"].toObject();
        MapInfo *mapInfo = new MapInfo(mapInfoObject);
        map->setMapInfo(mapInfo);
    } else {
        qWarning() << "MAP_LOADING: Clé 'mapInfo' manquante ou invalide - map chargée sans métadonnées";
    }

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

    // Créer MapInfo depuis JSON (avec vérification)
    if (jsonObject.contains("mapInfo") && jsonObject["mapInfo"].isObject()) {
        QJsonObject mapInfoObject = jsonObject["mapInfo"].toObject();
        MapInfo *mapInfo = new MapInfo(mapInfoObject);
        map->setMapInfo(mapInfo);
    } else {
        qWarning() << "MAP_LOADING: Clé 'mapInfo' manquante ou invalide - map chargée sans métadonnées";
    }

    return map;
}
