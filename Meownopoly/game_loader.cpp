#include "game.h"
#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include <QFile>
#include <QString>

#include "map/mapinfo.h"

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

bool Game::addTileToJson(QJsonObject jsonObject, QString mapName)
{

    QJsonDocument jsonDoc(jsonObject);
    QByteArray jsonData = jsonDoc.toJson(QJsonDocument::Indented);

    // Sauvegarder le fichier JSON
    QString fileName = "map/" +  mapName.toLower().replace(" ", "_") + "_map.json";
    QDir dir("map");
    if (!dir.exists()) {
        dir.mkpath(".");
    }
    QFile file(fileName);

    if (!file.open(QIODevice::WriteOnly)) {
        qDebug() << "Failed to open file for writing:" << fileName;
        return false;
    }

    qint64 bytesWritten = file.write(jsonData);
    file.close();

    if (bytesWritten == -1) {
        qDebug() << "Failed to write to file:" << fileName;
        return false;
    }

    qDebug() << "Map saved successfully to:" << fileName;
    qDebug().noquote() << QString::fromUtf8(jsonData);
    return true;
}

bool Game::registerMap(MapInfo* mapInfo, QVariantList caseList, QVariantList decorationList)
{
    QJsonArray snapableTilesArray;

    // Ajouter les informations de la map
    QJsonObject jsonObject;
    QString mapInfoJson = mapInfo->toJSON();
    QJsonDocument mapInfoDoc = QJsonDocument::fromJson(mapInfoJson.toUtf8());
    QJsonObject mapInfoObject = mapInfoDoc.object();

    jsonObject["mapInfo"] = mapInfoObject;

    for (int i = 0; i < caseList.size(); ++i) {
        QVariantList caseInfo = caseList.at(i).toList();
        if (caseInfo.size() >= 2) {
            // Extraction de caseData
            QVariant caseData = caseInfo.at(0);
            Case* currentCase = qvariant_cast<Case*>(caseData);

            // Extraction de displayInfo
            DisplayParameter* dp = qvariant_cast<DisplayParameter*>(caseInfo.at(1));

            ItemSnapable is(currentCase, dp);
            snapableTilesArray = formatTileDataToJson(is, snapableTilesArray);
        }
    }

    jsonObject["snapableTiles"] = snapableTilesArray;
    addTileToJson(jsonObject, mapInfo->getMapName());
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

