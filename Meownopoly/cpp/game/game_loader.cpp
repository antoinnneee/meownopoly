#include "game.h"
#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include <QFile>
#include <QString>
#include <QJsonDocument>

#include "map/mapinfo.h"
#include "map/mapfilemanager.h"
#include "map/maptypes.h"
#include "map/map.h"
#include "map/editdelta.h"
#include "qsettings.h"
#include "tools/logger.h"

QJsonArray Game::formatTileDataToJson(ItemSnapable &is, QJsonArray snapableTilesArray)
{
    QJsonParseError parseError;
    QString ISjsonDoc = is.toJSON();
    QJsonDocument tileDoc = QJsonDocument::fromJson(ISjsonDoc.toUtf8(), &parseError);
    if (parseError.error == QJsonParseError::NoError && tileDoc.isObject()) {
        snapableTilesArray.append(tileDoc.object());
    } else {
        Logger::instance()->error(QString("Error parsing ItemSnapable JSON: %1\n%2")
                                      .arg(parseError.errorString(), ISjsonDoc));
    }
    return snapableTilesArray;
}

bool Game::saveCurrentMap(){

    Map *currentMap = MapFileManager::instance()->getCurrentMap();
    MapInfo *currentMapInfo = currentMap->getMapInfo();
    MapTypes::MapType currentType = currentMapInfo->getType();

    QJsonObject jsonObject;

    QString mapInfoJson = currentMapInfo->toJSON(); QJsonDocument mapInfoDoc = QJsonDocument::fromJson(mapInfoJson.toUtf8());
    jsonObject["mapInfo"] = mapInfoDoc.object();

    QJsonArray snapableTilesArray;
    for (int i = 0; i < currentMap->tiles().size(); ++i) {
        ItemSnapable* currentTile = currentMap->tiles().at(i);
        snapableTilesArray = formatTileDataToJson(*currentTile, snapableTilesArray);
    }
    jsonObject["snapableTiles"] = snapableTilesArray;
    qDebug() << Q_FUNC_INFO << "Saving map with " << snapableTilesArray.size() << " snapable tiles.";
    return MapFileManager::saveMap(jsonObject, currentMapInfo->getMapName(), currentType);
}

bool Game::saveMap(MapInfo* mapInfo, QVariantList itemSnapableList, MapTypes::MapType mapType)
{
    qDebug() << Q_FUNC_INFO << mapInfo->getMapName() << " Type: " << mapType;
    Logger::instance()->info(QString("saveMap called %1, Type %2").arg(mapInfo->getMapName()).arg(mapType), "Game");

    QJsonArray snapableTilesArray;
    QJsonObject jsonObject;
    QString mapInfoJson = mapInfo->toJSON();
    QJsonDocument mapInfoDoc = QJsonDocument::fromJson(mapInfoJson.toUtf8());

    jsonObject["mapInfo"] = mapInfoDoc.object();

    for (int i = 0; i < itemSnapableList.size(); ++i) {
        ItemSnapable* currentTile = qvariant_cast<ItemSnapable*>(itemSnapableList.at(i));
        snapableTilesArray = formatTileDataToJson(*currentTile, snapableTilesArray);
    }
    jsonObject["snapableTiles"] = snapableTilesArray;

    switch (mapType) {
    case MapTypes::AUTOSAVE:
    case MapTypes::CUSTOM:
        return MapFileManager::saveMap(jsonObject, mapInfo->getMapName(), mapType);
    default:
        break;
    }
    return false;
}

bool Game::deleteMap(QString mapName, MapTypes::MapType mapType)
{
    return MapFileManager::removeMapFile(mapName, mapType);
}

Map *Game::loadMap(QString mapName, MapTypes::MapType mapType)
{
    Map *map = nullptr;
    switch (mapType) {
    case MapTypes::CUSTOM:
    case MapTypes::AUTOSAVE:
        map = Map::loadMap(mapName, mapType);
        break;
    default:
        qWarning() << Q_FUNC_INFO << "Unexpected mapType:" << mapType;
        break;
    }

    if (map) {
        // Initialiser les shadow copies pour toutes les tiles
        for (ItemSnapable *tile : map->tiles())
            tile->commitCurrentState();
        map->clearHistory();

        // Relay Map signals to Game
        connect(map, &Map::tileRemovedFromHistory, this, &Game::tileRemoved);
        connect(map, &Map::tileRestoredFromHistory, this, &Game::foundItemSnapableTile);
        connect(map, &Map::forceUnselectAll, this, &Game::forceUnselectAll);
        connect(map, &Map::afterRestoration, this, &Game::afterRestoration);

        for (ItemSnapable *tile : map->tiles())
            emit foundItemSnapableTile(tile);
        emit mapLoaded(map);
    }
    MapFileManager::instance()->setCurrentMap(map);    
    return map;
}

QList<ItemSnapable*> Game::generateItems(QJsonObject jsonObject)
{
    QList<ItemSnapable*> listItems;
    QJsonArray snapableTilesArray = jsonObject["snapableTiles"].toArray();
    for (const QJsonValueRef value : snapableTilesArray) {
        QJsonObject tileObject = value.toObject();
        ItemSnapable *is = new ItemSnapable(tileObject);
        QQmlEngine::setObjectOwnership(is, QQmlEngine::JavaScriptOwnership);
        listItems.append(is);
    }
    return listItems;
}

void Game::askPreview()
{
    qDebug() << "[GAME] askPreview() appelé";
    Map *map = MapFileManager::instance()->getCurrentMap();
    if (!map){ qDebug() << "Current map is Null, returning;"; return;}

    map->undo();

    if (saveOnEdit())
        qDebug() << "saveOnEdit is enabled, saving current map return " << Game::saveCurrentMap();
}

void Game::askNext()
{
    Map *map = MapFileManager::instance()->getCurrentMap();
    if (!map){ qDebug() << "Current map is Null, returning;"; return;}

    map->redo();

    if (saveOnEdit())
        qDebug() << "saveOnEdit is enabled, saving current map return " << Game::saveCurrentMap();
}

// ---- Delta undo/redo ----

bool Game::saveOnEdit(){

    QSettings setting;
    bool flag = false;

    setting.beginGroup("Editor/SaveConfig");
    flag = setting.value("saveEvent") == "3";
    return flag;
}

void Game::updateMap(int type, ItemSnapable* tile, QUuid groupId)
{
    Map *map = MapFileManager::instance()->getCurrentMap();
    if (!map || !map->canSave() || !tile) {
        qDebug() << Q_FUNC_INFO << " Can't update editState "
                 << (map ? "map is valid, " : "map is null, ")
                 << (map && map->canSave() ? "mapCanSave == true " : "mapCanSave == false ")
                 << (tile ? "tile is valid." : "tile is null.") << " Returning.";
        return;
    }

    const auto deltaType = static_cast<EditDeltaType::Type>(type);

    EditDelta delta;
    delta.type    = deltaType;
    delta.tileId  = tile->uniqueId();
    delta.groupId = groupId.isNull() ? m_currentTransaction : groupId;
    delta.before  = QJsonDocument::fromJson(tile->lastKnownJson().toUtf8()).object();
    delta.after   = QJsonDocument::fromJson(tile->toJSON().toUtf8()).object();

    // Mutation de m_tiles et ajustement du delta selon le type
    switch (deltaType) {
    case EditDeltaType::TileAdded:
        delta.before = {};
        if (!map->tileById(tile->uniqueId())) {
            QQmlEngine::setObjectOwnership(tile, QQmlEngine::CppOwnership);
            map->addTile(tile);
        }
        break;
    case EditDeltaType::TileDeleted:
        delta.after = {};
        // Retire de m_tiles immédiatement (stashe pour deleteLater ultérieur)
        map->removeTile(tile->uniqueId());
        break;
    case EditDeltaType::TileModified:
    case EditDeltaType::MetadataChanged:
        // Rien à muter ici : la tile est déjà en place et mutée par QML
        // (pour Modified), ou le flux passe par updateMapMetadata.
        break;
    }

    map->pushDelta(delta);

    if (deltaType != EditDeltaType::TileDeleted)
        tile->commitCurrentState();

    // Sauvegarde : différée si en transaction, sinon immédiate si saveOnEdit
    if (!m_currentTransaction.isNull()) {
        m_txDirty = true;
    } else if (saveOnEdit()) {
        qDebug() << Q_FUNC_INFO << "saveOnEdit -> save return " << Game::saveCurrentMap();
    }
}

void Game::updateMapMetadata(const QString& beforeJson, const QString& afterJson)
{
    Map *map = MapFileManager::instance()->getCurrentMap();
    if (!map || !map->canSave())
        return;

    EditDelta delta;
    delta.type   = EditDeltaType::MetadataChanged;
    delta.before = QJsonDocument::fromJson(beforeJson.toUtf8()).object();
    delta.after  = QJsonDocument::fromJson(afterJson.toUtf8()).object();
    delta.groupId = m_currentTransaction;
    map->pushDelta(delta);

    if (!m_currentTransaction.isNull()) {
        m_txDirty = true;
    } else if (saveOnEdit()) {
        qDebug() << Q_FUNC_INFO << "saveOnEdit -> save return " << Game::saveCurrentMap();
    }
}

QUuid Game::beginTransaction()
{
    m_currentTransaction = QUuid::createUuid();
    m_txDirty = false;
    return m_currentTransaction;
}

void Game::commitTransaction()
{
    m_currentTransaction = QUuid();
    if (m_txDirty && saveOnEdit()) {
        qDebug() << Q_FUNC_INFO << "saveOnEdit -> save return " << Game::saveCurrentMap();
    }
    m_txDirty = false;
}

void Game::finalizeDeletedTile(const QUuid &tileId)
{
    Map *map = MapFileManager::instance()->getCurrentMap();
    if (!map) return;
    map->finalizeTile(tileId);  // no-op si déjà finalisé
}
