#ifndef MAPFILEMANAGER_H
#define MAPFILEMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QStringList>
#include <QQmlEngine>
#include "map/maptypes.h"

#define MAP_FILE_PATH (BUILD_DIR "/map/")
#define AUTOSAVE_MAP_NAME "autosave_tmp"

class MapFileManager : public QObject
{
    Q_OBJECT
public:
    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static MapFileManager *instance();

    // Lecture
    Q_INVOKABLE static QJsonObject readMapFile(const QString &mapName, MapTypes::MapType mapType);
    Q_INVOKABLE static QStringList getAvailableMaps();
    Q_INVOKABLE static QString findMapFileByName(const QString &displayName);
    Q_INVOKABLE static bool mapExists(const QString &mapName, MapTypes::MapType mapType);
    
    // Ã‰criture
    Q_INVOKABLE static bool saveMap(const QJsonObject &mapData, const QString &mapName, MapTypes::MapType mapType);
    Q_INVOKABLE static QString createMapFile(const QString &mapName, MapTypes::MapType mapType);
    Q_INVOKABLE static bool removeMapFile(const QString &mapName, MapTypes::MapType mapType);
    
    // Utilitaires
    static QString normalizeMapName(const QString &mapName);

private:
    explicit MapFileManager(QObject *parent = nullptr);
    static MapFileManager *m_instance;
    static QString getMapFilePath(const QString &mapName, MapTypes::MapType mapType);
};

#endif // MAPFILEMANAGER_H
