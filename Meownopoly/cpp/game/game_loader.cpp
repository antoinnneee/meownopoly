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

QJsonArray Game::formatTileDataToJson(ItemSnapable &is, QJsonArray snapableTilesArray)
{
    QJsonParseError parseError;
    QString ISjsonDoc = is.toJSON();
    QJsonDocument tileDoc = QJsonDocument::fromJson(ISjsonDoc.toUtf8(), &parseError);
    if (parseError.error == QJsonParseError::NoError && tileDoc.isObject()) {
        snapableTilesArray.append(tileDoc.object());
    } else {
        qDebug().noquote() << "Error parsing ItemSnapable JSON:" << parseError.errorString()<< "\n" << ISjsonDoc;
    }
    return snapableTilesArray;
}

bool Game::saveMap(MapInfo* mapInfo, QVariantList itemSnapableList, MapTypes::MapType mapType)
{
    qDebug() << "Game::saveMap called " << mapInfo->getMapName() << " Type: " << mapType;
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
        flag = true;
        emit updateListEdits(jsonObject);
        break;
    default:
        break;
    }
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

        // Emettre les signaux immediatement car Map ne les émet plus
        for (ItemSnapable *tile : map->tiles()) {
            emit foundItemSnapableTile(tile);
        }
        emit mapLoaded(map);
    }
}

QList<ItemSnapable*> Game::generateItems(QJsonObject jsonObject)
{
    QList<ItemSnapable*> listItems;
    QJsonArray snapableTilesArray = jsonObject["snapableTiles"].toArray();
    for (const QJsonValueRef value : snapableTilesArray) {
        QJsonObject tileObject = value.toObject();
        ItemSnapable *is = new ItemSnapable(tileObject);
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
