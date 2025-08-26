#include "game.h"
#include <QDebug>

#include <QQmlApplicationEngine>
#include <QQmlEngine>

#include <QFile>
#include <QString>


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
    QString fileName = mapName.toLower().replace(" ", "_") + "_map.json";
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

DisplayParameter *Game::getDisplayerParameter(const QVariantMap &displayInfoMap) {
    int unit_s_w = displayInfoMap["unitSizeWidth"].toInt();
    int unit_s_h = displayInfoMap["unitSizeHeight"].toInt();
    int gr_p_x = displayInfoMap["gridRelativePositionX"].toInt();
    int gr_p_y = displayInfoMap["gridRelativePositionY"].toInt();
    int zLayer = displayInfoMap["zLayer"].toInt();
    DisplayParameter *dp = new DisplayParameter(unit_s_w, unit_s_h, gr_p_x, gr_p_y, zLayer);
    return dp;
}

bool Game::registerMap(QVariantMap mapInfo, QVariantList caseList, QVariantList decorationList)
{
    QJsonArray snapableTilesArray;

    // Ajouter les informations de la map
    QJsonObject jsonObject;

    // Extraire le nom de la map du QVariantMap
    QString mapName = "mapName"; // valeur par défaut
    if (mapInfo.contains("name")) {
        mapName = mapInfo["name"].toString();
    }

    jsonObject["name"] = mapName;
    jsonObject["version"] = "version X";
    jsonObject["description"] = "description X";


    for (int i = 0; i < caseList.size(); ++i) {
        QVariantList caseInfo = caseList.at(i).toList();
        if (caseInfo.size() >= 2) {
            // Extraction de caseData
            QVariant caseData = caseInfo.at(0);
            Case* currentCase = qvariant_cast<Case*>(caseData);

            // Extraction de displayInfo
            QVariantMap displayInfoMap = caseInfo.at(1).toMap();
            DisplayParameter* dp = getDisplayerParameter(displayInfoMap);

            ItemSnapable is(currentCase, dp);
            snapableTilesArray = formatTileDataToJson(is, snapableTilesArray);
        }
    }

    jsonObject["snapableTiles"] = snapableTilesArray;
    addTileToJson(jsonObject, mapName);
    return true;
}

