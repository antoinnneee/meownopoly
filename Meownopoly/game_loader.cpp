#include "game.h"
#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include <QFile>
#include <QString>

#include "map/mapinfo.h"
#include "map/maploader.h"

// Helper function to normalize map names for consistent file naming
QString normalizeMapName(const QString &mapName) {
    QString normalized = mapName.toLower();
    normalized = normalized.replace(" ", "_");
    normalized = normalized.trimmed();
    return normalized;
}


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

bool Game::addTileToJson(QJsonObject jsonObject, QString mapName, MapLoader::MapType isAutoSave)
{

    QJsonDocument jsonDoc(jsonObject);
    QByteArray jsonData = jsonDoc.toJson(QJsonDocument::Indented);

    QDir dir("map");
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    QFile map;

    switch (isAutoSave) {
    case MapLoader::AUTOSAVE:
        map.setFileName((QString)MAP_FILE_PATH + (QString)AUTOSAVE_MAP_NAME + ".json");
        break;
    case MapLoader::CUSTOM:
        map.setFileName((QString)MAP_FILE_PATH + normalizeMapName(mapName) + "_map.json");
        break;
    // case MapLoader::UNDOREDO:
    //     break;
    }

    if (!map.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        qDebug() << "Failed to open file for writing:" << map.fileName();
        return false;
    }

    qint64 bytesWritten = map.write(jsonData);
    map.close();

    if (bytesWritten == -1) {
        qDebug() << "Failed to write to file:" << map.fileName();
        return false;
    }

    qDebug() << "Map saved successfully to:" << map.fileName();
    qDebug().noquote() << QString::fromUtf8(jsonData);
    return true;
}

bool Game::registerMap(MapInfo* mapInfo, QVariantList caseList, QVariantList decorationList, MapLoader::MapType isAutoSave)
{
    QJsonArray snapableTilesArray;
    QJsonObject jsonObject;

    // TO DELETE
    //Get mapInfo as QJsonObject
    QString mapInfoJson = mapInfo->toJSON();
    QJsonDocument mapInfoDoc = QJsonDocument::fromJson(mapInfoJson.toUtf8());
    QJsonObject mapInfoObject = mapInfoDoc.object();

    // QJsonObject mapInfoObject = QJsonDocument::fromJson(mapInfo->toJSON().toUtf8()).object();

    for (int i = 0; i < itemSnapableList.size(); ++i) {
        QVariant itemSnapable = itemSnapableList.at(i);
        ItemSnapable* currentTile = qvariant_cast<ItemSnapable*>(itemSnapable);

        snapableTilesArray = formatTileDataToJson(*currentTile, snapableTilesArray);
    }

    jsonObject["mapInfo"] = mapInfoObject;
    jsonObject["snapableTiles"] = snapableTilesArray;

    addTileToJson(jsonObject, mapInfo->getMapName(), isAutoSave);
    return true;
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

