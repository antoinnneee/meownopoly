#include "game.h"
#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include <QFile>
#include <QString>

#include "map/mapinfo.h"
#include "map/maploader.h"


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
        map.setFileName((QString)MAP_FILE_PATH + mapName + "_map.json");
        break;
    // case MapLoader::UNDOREDO:
    //     break;
    }

    if (!map.open(QIODevice::ReadWrite)) {
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

    //Get cases and decorations as QJsonArray
    for (int i = 0; i < caseList.size(); ++i) {
        QVariantList caseInfo = caseList.at(i).toList();
        if (caseInfo.size() >= 2) {
            // Extraction de caseData
            QVariant caseData = caseInfo.at(0);
            Case* currentCase = qvariant_cast<Case*>(caseData);

            // Extraction de displayInfo
            DisplayParameter* displayParameter = qvariant_cast<DisplayParameter*>(caseInfo.at(1));

            ItemSnapable is(currentCase, displayParameter);
            snapableTilesArray = formatTileDataToJson(is, snapableTilesArray);
        }
    }

    for (int i = 0; i < decorationList.size(); ++i) {

        QVariantList decorationInfo = decorationList.at(i).toList();
        if (decorationInfo.size() >= 2) {
            DecorationParameter* decorationParameter = qvariant_cast<DecorationParameter*>(decorationInfo.at(0));
            DisplayParameter* displayParameter = qvariant_cast<DisplayParameter*>(decorationInfo.at(1));

            ItemSnapable is(decorationParameter, displayParameter);
            snapableTilesArray = formatTileDataToJson(is, snapableTilesArray);
        }
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

