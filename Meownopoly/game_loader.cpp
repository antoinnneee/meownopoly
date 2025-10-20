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
#include "tools/undoredomanager.h"

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
    return MapFileManager::saveMap(jsonObject, mapInfo->getMapName(), mapType);
}

Map *Game::loadMap(QString mapName, MapTypes::MapType mapType)
{
    return Map::loadFromFile(mapName, mapType);
}

QStringList Game::getAvailableMaps()
{
    return MapFileManager::getAvailableMaps();
}

QString Game::findMapFileByName(const QString &displayName)
{
    return MapFileManager::findMapFileByName(displayName);
}

bool Game::mapExists(const QString &mapName, MapTypes::MapType mapType)
{
    return MapFileManager::mapExists(mapName, mapType);
}

QString Game::createMapFile(const QString &mapName, MapTypes::MapType mapType)
{
    return MapFileManager::createMapFile(mapName, mapType);
}

bool Game::removeMapFile(const QString &mapName, MapTypes::MapType mapType)
{
    return MapFileManager::removeMapFile(mapName, mapType);
}

void Game::onReturnEdit(QJsonObject newEdit)
{
    // Slot vide comme dans MapLoader original
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