#ifndef MAPFILEMANAGER_H
#define MAPFILEMANAGER_H

#include <QObject>
#include <QJsonObject>
#include <QStringList>
#include <QQmlEngine>
#include <QLockFile>
#include "maptypes.h"
#include "map.h"

#define MAP_FILE_PATH ("./map/")

class MapFileManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(Map *currentMap READ getCurrentMap WRITE setCurrentMap NOTIFY currentMapChanged FINAL)

public:
    explicit MapFileManager(QObject *parent = nullptr);
    ~MapFileManager();

    // QML registration
    static void registerQml();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static MapFileManager *instance();

    // Méthodes QML (instance, Q_INVOKABLE)
    Q_INVOKABLE bool mapExists(const QString &mapName, MapTypes::MapType mapType);
    Q_INVOKABLE QStringList getAvailableMaps();
    Q_INVOKABLE QString findMapFileByName(const QString &displayName);
    Q_INVOKABLE QString createMapFile(const QString &mapName, MapTypes::MapType mapType);
    Q_INVOKABLE bool isAutosaveMap(const QString &mapName);
    Q_INVOKABLE bool isCustomAutosaveMap();
    Q_INVOKABLE MapTypes::MapType getMapType(const QString &mapName);


    // Méthodes C++ internes (static)
    static QJsonObject readMapFile(const QString &mapName, MapTypes::MapType mapType);
    static bool saveMap(const QJsonObject &mapData, const QString &mapName, MapTypes::MapType mapType);
    static bool removeMapFile(const QString &mapName, MapTypes::MapType mapType);

    // Utility methods (static). normalizeMapName est également Q_INVOKABLE
    // parce que la QML `MapNavigationBar.syncCurrentIndex` en a besoin pour
    // comparer `mapInfo.mapName` (casse d'origine) aux noms de fichier
    // (toujours en lowercase + `_`). Sans normalisation symétrique, le match
    // échoue et currentIndex retombe à 0.
    Q_INVOKABLE static QString normalizeMapName(const QString &mapName);
    static QString getMapFilePath(const QString &mapName, MapTypes::MapType mapType);

    Map *getCurrentMap() const;
    void setCurrentMap(Map *newCurrentMap);

signals:
    void currentMapChanged();

private:

    static MapFileManager *m_instance;
    Map *currentMap = nullptr;
};

#endif // MAPFILEMANAGER_H
