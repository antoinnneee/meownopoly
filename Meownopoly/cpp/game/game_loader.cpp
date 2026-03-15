#include "game.h"
#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include <QFile>
#include <QString>

#include "map/mapinfo.h"
#include "map/mapfilemanager.h"
#include "map/maptypes.h"
#include "map/map.h"
#include "game/map/undoredomanager.h"
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
        QString errorString = "Error parsing ItemSnapable JSON:" ;
        errorString.append(parseError.errorString()).append("\n").append(ISjsonDoc);
        // Logger:: <<
        Logger::instance()->error(errorString);
    }
    return snapableTilesArray;
}

bool Game::saveMap(MapInfo* mapInfo, QVariantList itemSnapableList, MapTypes::MapType mapType)
{
    qDebug() << "Game::saveMap called " << mapInfo->getMapName() << " Type: " << mapType;
    Logger::instance()->info(QString("saveMap called %1, Type %2").arg(mapInfo->getMapName()).arg(mapType), "Game");
    bool flag = false;
    QJsonArray snapableTilesArray;

    // Ajouter les informations de la map
    QJsonObject jsonObject;
    QString mapInfoJson = mapInfo->toJSON();
    QJsonDocument mapInfoDoc = QJsonDocument::fromJson(mapInfoJson.toUtf8());
    QJsonObject mapInfoObject = mapInfoDoc.object();

    jsonObject["mapInfo"] = mapInfoObject;

    for (int i = 0; i < itemSnapableList.size(); ++i) {
        QVariant itemSnapable = itemSnapableList.at(i);
        ItemSnapable* currentTile = qvariant_cast<ItemSnapable*>(itemSnapable);

        snapableTilesArray = formatTileDataToJson(*currentTile, snapableTilesArray);
    }

    jsonObject["snapableTiles"] = snapableTilesArray;
    QSettings settings;
    switch (mapType) {
    case MapTypes::AUTOSAVE:
    case MapTypes::CUSTOM:
        flag = MapFileManager::saveMap(jsonObject, mapInfo->getMapName(), mapType);
        break;
    case MapTypes::UNDOREDO:
        if (compareMap(itemSnapableList, jsonObject)) {
            emit updateListEdits(jsonObject);
        } else {
            Logger::instance()->info("UNDOREDO: no changes detected, skipping save", "Game");
        }
        flag = true;
        break;
    default:
        break;
    }
    return flag;
}

// Retourne true si des changements ont �t� d�tect�s (la carte doit �tre sauvegard�e),
// false si l'�tat est identique au dernier edit conserv� dans UndoRedoManager.
bool Game::compareMap(const QVariantList& itemSnapableList, const QJsonObject& newJsonState)
{
    QJsonObject lastEdit = UndoRedoManager::instance()->getLastEdit();

    // Pas d'�tat pr�c�dent : premier enregistrement, toujours sauvegarder
    if (lastEdit.isEmpty())
        return true;

    // --- Comparaison des tiles ---
    QJsonArray oldTiles = lastEdit["snapableTiles"].toArray();
    QJsonArray newTiles = newJsonState["snapableTiles"].toArray();

    if (oldTiles.size() != newTiles.size())
        return true;

    // Indexer les anciens tiles par uniqueId pour une recherche en O(1)
    QMap<QString, QJsonObject> oldTileMap;
    for (const QJsonValue& v : oldTiles)
        oldTileMap[v.toObject()["uniqueId"].toString()] = v.toObject();

    for (int i = 0; i < itemSnapableList.size(); ++i) {
        ItemSnapable* newTile = qvariant_cast<ItemSnapable*>(itemSnapableList.at(i));
        if (!newTile) continue;

        QString id = newTile->uniqueId().toString();
        if (!oldTileMap.contains(id))
            return true; // tile ajout�e

        // Comparaison JSON du tile (inclut displayParameter, decorationParameter,
        // zoneParameter, caseData, next/prev s�rialis�s en UUID)
        QJsonParseError parseError;
        QJsonObject newTileJson = QJsonDocument::fromJson(newTile->toJSON().toUtf8(), &parseError).object();
        if (parseError.error != QJsonParseError::NoError)
            return true; // En cas d'erreur de s�rialisation, sauvegarder par s�curit�

        if (oldTileMap[id] != newTileJson)
            return true; // tile modifi�e
    }

    // --- Comparaison des m�tadonn�es (mapLastModified exclu car toujours mis � jour) ---
    QJsonObject oldMeta = lastEdit["mapInfo"].toObject();
    QJsonObject newMeta = newJsonState["mapInfo"].toObject();

    static const QStringList metaKeys = {
        "mapName", "mapDescription", "mapCreationDate", "version",
        "musicPath", "backgroundPath", "backgroundScaling",
        "isBackgroundOnGrill", "backgroundTileSize"
    };
    for (const QString& key : metaKeys) {
        if (oldMeta.value(key) != newMeta.value(key))
            return true;
    }

    return false; // Aucun changement d�tect�
}


bool Game::deleteMap(QString mapName, MapTypes::MapType mapType)
{
    bool flag = false;
    flag = MapFileManager::removeMapFile(mapName, mapType);
    return flag;
}

Map *Game::loadMap(QString mapName, MapTypes::MapType mapType)
{
    Map *map = nullptr;
    switch (mapType) {
    case MapTypes::CUSTOM:
    case MapTypes::AUTOSAVE:
        map = Map::loadMap(mapName, mapType);
        break;
    case MapTypes::UNDOREDO:
        qWarning() << Q_FUNC_INFO << "  - SHOULD NOT BEEN SEEN WITH UNDOREDO TYPE";
        break;
    }
    
    if (map) {
        // Relayer les signaux de Map vers Game
        connect(map, &Map::foundItemSnapableTile, this, &Game::foundItemSnapableTile);
        connect(map, &Map::mapLoaded, this, &Game::mapLoaded);
        
        // Emettre les signaux immediatement car Map ne les emet plus
        for (ItemSnapable *tile : map->tiles()) {
            emit foundItemSnapableTile(tile);
        }
        emit mapLoaded(map);
    }
    MapFileManager::instance()->setCurrentMap(map);
    return map;
}


void Game::onReturnEdit(QJsonObject newEdit)
{

    emit clearCurrentMap();

    Map *map = Map::loadMap(newEdit);
    if (map) {
        // Relayer les signaux de Map vers Game
        connect(map, &Map::foundItemSnapableTile, this, &Game::foundItemSnapableTile);
        connect(map, &Map::mapLoaded, this, &Game::mapLoaded);

        // Emettre les signaux immediatement car Map ne les �met plus
        for (ItemSnapable *tile : map->tiles()) {
            emit foundItemSnapableTile(tile);
        }
        emit mapLoaded(map);
        MapFileManager::instance()->setCurrentMap(map);
    }
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
    askEdit(UndoRedoManager::Preview);
}

void Game::askNext()
{
    askEdit(UndoRedoManager::Next);
}
