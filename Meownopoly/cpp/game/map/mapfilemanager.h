#ifndef MAPFILEMANAGER_H
#define MAPFILEMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QStringList>
#include <QQmlEngine>
#include "maptypes.h"

#define MAP_FILE_PATH ("./map/")

class MapFileManager : public QObject
{
    Q_OBJECT

public:
    // QML registration
    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static MapFileManager *instance();

    // Méthodes QML (instance, Q_INVOKABLE)
    Q_INVOKABLE bool mapExists(const QString &mapName, MapTypes::MapType mapType);
    Q_INVOKABLE bool renameMap(QString oldMapName, QString newMapName);
    Q_INVOKABLE QStringList getAvailableMaps();
    Q_INVOKABLE QString findMapFileByName(const QString &displayName);
    Q_INVOKABLE QString createMapFile(const QString &mapName, MapTypes::MapType mapType);
    Q_INVOKABLE bool isAutosaveMap(const QString &mapName);
    Q_INVOKABLE MapTypes::MapType getMapType(const QString &mapName);


    // Méthodes C++ internes (static)
    static QJsonObject readMapFile(const QString &mapName, MapTypes::MapType mapType);
    static bool saveMap(const QJsonObject &mapData, const QString &mapName, MapTypes::MapType mapType);
    static bool removeMapFile(const QString &mapName, MapTypes::MapType mapType);
    
    // Utility methods (static)
    static QString normalizeMapName(const QString &mapName);
    static QString getMapFilePath(const QString &mapName, MapTypes::MapType mapType);

private:
    explicit MapFileManager(QObject *parent = nullptr);
    static MapFileManager *m_instance;
};

#endif // MAPFILEMANAGER_H
