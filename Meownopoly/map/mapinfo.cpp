#include "mapinfo.h"
#include <QQmlEngine>

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QJsonValue>
#include <QJsonValueRef>

MapInfo::MapInfo() {}

MapInfo::MapInfo(const QJsonObject &json)
{
    m_mapName = json["name"].toString();
    m_mapDescription = json["description"].toString();
    m_mapCreationDate = json["creation"].toString();
    m_mapLastModified = json["lastModified"].toString();
    m_version = json["version"].toInt();
}

QString MapInfo::toJSON()
{
    QJsonObject json;
    json["name"] = m_mapName;
    json["description"] = m_mapDescription;
    json["creation"] = m_mapCreationDate;
    json["lastModified"] = m_mapLastModified;
    json["version"] = m_version;
    return QJsonDocument(json).toJson(QJsonDocument::Indented);
}

void MapInfo::registerQml()
{
    qmlRegisterType<MapInfo>("MapInfo", 1, 0, "MapInfo");
}

void MapInfo::setMapName(const QString &mapName)
{
    m_mapName = mapName;
    emit mapNameChanged(mapName);
}

void MapInfo::setMapDescription(const QString &mapDescription)
{
    m_mapDescription = mapDescription;
    emit mapDescriptionChanged(mapDescription);
}

void MapInfo::setMapCreationDate(const QString &newMapCreationDate)
{
    if (m_mapCreationDate == newMapCreationDate)
        return;
    m_mapCreationDate = newMapCreationDate;
    emit mapCreationDateChanged();
}

QString MapInfo::getMusicPath() const
{
    return musicPath;
}

void MapInfo::setMusicPath(const QString &newMusicPath)
{
    if (musicPath == newMusicPath)
        return;
    musicPath = newMusicPath;
    emit musicPathChanged();
}

QString MapInfo::getBackgroundPath() const
{
    return backgroundPath;
}

void MapInfo::setBackgroundPath(const QString &newBackgroundPath)
{
    if (backgroundPath == newBackgroundPath)
        return;
    backgroundPath = newBackgroundPath;
    emit backgroundPathChanged();
}

QString MapInfo::getBackgroundScaling() const
{
    return backgroundScaling;
}

void MapInfo::setBackgroundScaling(const QString &newBackgroundScaling)
{
    if (backgroundScaling == newBackgroundScaling)
        return;
    backgroundScaling = newBackgroundScaling;
    emit backgroundScalingChanged();
}

bool MapInfo::getIsBackgroundOnGrill() const
{
    return isBackgroundOnGrill;
}

void MapInfo::setIsBackgroundOnGrill(bool newIsBackgroundOnGrill)
{
    if (isBackgroundOnGrill == newIsBackgroundOnGrill)
        return;
    isBackgroundOnGrill = newIsBackgroundOnGrill;
    emit isBackgroundOnGrillChanged();
}

int MapInfo::getBackgroundTileSize() const
{
    return backgroundTileSize;
}

void MapInfo::setBackgroundTileSize(int newBackgroundTileSize)
{
    if (backgroundTileSize == newBackgroundTileSize)
        return;
    backgroundTileSize = newBackgroundTileSize;
    emit backgroundTileSizeChanged();
}


void MapInfo::setMapLastModified(const QString &mapLastModified)
{
    m_mapLastModified = mapLastModified;
    emit mapLastModifiedChanged(mapLastModified);
}

void MapInfo::setVersion(int version)
{
    m_version = version;
    emit versionChanged(version);
}

QString MapInfo::getMapName() const
{
    return m_mapName;
}

QString MapInfo::getMapDescription() const
{
    return m_mapDescription;
}

QString MapInfo::getMapLastModified() const
{
    return m_mapLastModified;
}

int MapInfo::getVersion() const
{
    return m_version;
}


QString MapInfo::mapCreationDate() const
{
    return m_mapCreationDate;
}
