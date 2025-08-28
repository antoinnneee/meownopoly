#include "map.h"


#include <QJsonArray>
#include <QJsonObject>

Map::Map(QObject *parent) : QObject(parent)
{
}

Map::Map(QJsonObject jsonObject, QObject *parent) : QObject(parent)
{
    m_mapName = jsonObject["name"].toString();
    m_mapVersion = jsonObject["version"].toString();
    m_mapDescription = jsonObject["description"].toString();

    qDebug() << "--------------------------------";
    qDebug() << "Start loading map:" << m_mapName;
    qDebug() << "Map version:" << m_mapVersion;
    qDebug() << "Map description:" << m_mapDescription;
    qDebug() << "--------------------------------";

    QJsonArray snapableTilesArray = jsonObject["snapableTiles"].toArray();
    qDebug() << "Snapable tiles:" << snapableTilesArray.size();
    qDebug() << "--------------------------------";
    qDebug() << "Start loading snapable tiles";


    for (const QJsonValueRef value : snapableTilesArray) {
        const QJsonObject tileObject = value.toObject();
        if (tileObject.contains("caseData")) {
            ItemSnapable *is = new ItemSnapable(tileObject);
            m_caseTiles.append(is);
        }
        else if (tileObject.contains("decorationParameter")) {
            ItemSnapable *is = new ItemSnapable(tileObject);
            m_decorationTiles.append(is);
        }
    }
    qDebug() << "Snapable tiles loaded successfully";
    qDebug() << "--------------------------------";
    qDebug() << "building links between snapable tiles";
    for (ItemSnapable *is : std::as_const(m_caseTiles)) {
        Case *caseData = is->caseData();
        QJsonObject originalJson = is->getOriginalJson();
        QJsonObject caseDataJson = originalJson["caseData"].toObject();
        QJsonArray nextIdArray = caseDataJson["next"].toArray();

        for (const QJsonValueRef value : nextIdArray) {
            QString nextId = value.toString();
            for (ItemSnapable *targetTile : m_caseTiles) {
                if (targetTile->caseData()->uniqueId().toString() == nextId) {
                    caseData->addNext(targetTile->caseData());
                    targetTile->caseData()->addPrev(caseData);
                    qDebug() << "Link built between" << caseData->name() << "and" << targetTile->caseData()->name();
                }
            }
        }
    }
    qDebug() << "Links built successfully";

    qDebug() << "--------------------------------";

}
