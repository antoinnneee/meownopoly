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

    m_backgroundPath = json["backgroundPath"].toString();
    m_backgroundScaling = json["backgroundScaling"].toString();
    m_backgroundTileSize = json["backgroundTileSize"].toInt(50);

    m_musicPath = json["musicPath"].toString();

}

QString MapInfo::toJSON()
{
    QJsonObject json;
    json["name"] = m_mapName;
    json["description"] = m_mapDescription;
    json["creation"] = m_mapCreationDate;
    json["lastModified"] = m_mapLastModified;
    json["version"] = m_version;

    json["backgroundPath"] = m_backgroundPath;
    json["backgroundScaling"] = m_backgroundScaling;
    json["backgroundTileSize"] = m_backgroundTileSize;

    json["musicPath"] = m_musicPath;

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
    return m_musicPath;
}

void MapInfo::setMusicPath(const QString &newMusicPath)
{
    if (m_musicPath == newMusicPath)
        return;
    m_musicPath = newMusicPath;
    emit musicPathChanged();
}

QString MapInfo::getBackgroundPath() const
{
    return m_backgroundPath;
}

void MapInfo::setBackgroundPath(const QString &newBackgroundPath)
{
    if (m_backgroundPath == newBackgroundPath)
        return;
    m_backgroundPath = newBackgroundPath;
    emit backgroundPathChanged();
}

QString MapInfo::getBackgroundScaling() const
{
    return m_backgroundScaling;
}

void MapInfo::setBackgroundScaling(const QString &newBackgroundScaling)
{
    if (m_backgroundScaling == newBackgroundScaling)
        return;
    m_backgroundScaling = newBackgroundScaling;
    emit backgroundScalingChanged();
}

bool MapInfo::getIsBackgroundOnGrill() const
{
    return m_isBackgroundOnGrill;
}

void MapInfo::setIsBackgroundOnGrill(bool newIsBackgroundOnGrill)
{
    if (m_isBackgroundOnGrill == newIsBackgroundOnGrill)
        return;
   m_isBackgroundOnGrill = newIsBackgroundOnGrill;
    emit isBackgroundOnGrillChanged();
}

int MapInfo::getBackgroundTileSize() const
{
    return m_backgroundTileSize;
}

void MapInfo::setBackgroundTileSize(int newBackgroundTileSize)
{
    if (m_backgroundTileSize == newBackgroundTileSize)
        return;
    m_backgroundTileSize = newBackgroundTileSize;
    emit backgroundTileSizeChanged();
}

QString MapInfo::autosaveMapName() const
{
    return m_autosaveMapName;
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
