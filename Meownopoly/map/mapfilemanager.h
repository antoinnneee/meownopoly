#ifndef MAPFILEMANAGER_H
#define MAPFILEMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QStringList>
#include <QQmlEngine>
#include "map/maptypes.h"

#define MAP_FILE_PATH (BUILD_DIR "/map/")
#define AUTOSAVE_MAP_NAME "autosave"

class MapFileManager : public QObject
{
    Q_OBJECT

public:
    // QML registration
    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static MapFileManager *instance();

    // Reading operations
    static QJsonObject readMapFile(const QString &mapName, MapTypes::MapType mapType);
    static QStringList getAvailableMaps();
    static QString findMapFileByName(const QString &displayName);
    static bool mapExists(const QString &mapName, MapTypes::MapType mapType);

    // Writing operations
    static bool saveMap(const QJsonObject &mapData, const QString &mapName, MapTypes::MapType mapType);
    static QString createMapFile(const QString &mapName, MapTypes::MapType mapType);
    static bool removeMapFile(const QString &mapName, MapTypes::MapType mapType);

    static QString getMapFilePath(const QString &mapName, MapTypes::MapType mapType);
    // Utility methods
    static QString normalizeMapName(const QString &mapName);

private:
    explicit MapFileManager(QObject *parent = nullptr);
    static MapFileManager *m_instance;
};

#endif // MAPFILEMANAGER_H
