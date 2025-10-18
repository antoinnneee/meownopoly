#ifndef MAPLOADER_H
#define MAPLOADER_H

#include <QObject>
#include <QQmlEngine>
#include "map/map.h"

#define MAP_FILE_PATH (BUILD_DIR "/map/")


class MapLoader : public QObject
{
    Q_OBJECT

public:

    enum MapType{
        AUTOSAVE,
        CUSTOM
        // UNDOREDO
    };

    Q_ENUM(MapType)

    static void registerQml();
    static MapLoader *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE bool mapAlreadyExist(const QString &mapName, MapType mapType);
    Q_INVOKABLE QString createJsonMap(const QString &mapName, MapType mapType);
    Q_INVOKABLE bool removeJsonMap(const QString &mapName, MapType mapType);
    Q_INVOKABLE Map *loadMap(QString mapName, MapType mapType);
    Q_INVOKABLE QStringList getAvailableMaps();
    Q_INVOKABLE QString findMapFileByName(const QString &displayName);

    static QJsonObject readMapFile(QString mapName, MapType mapType);

public slots:

signals:
    void mapLoaded(Map *map);
    void foundCaseTile(DisplayParameter *dp, Case *caseData);
    void foundDecorationTile(DisplayParameter *displayParameter, DecorationParameter *decorationParameter);

private slots:

private:
    explicit MapLoader(QObject *parent = nullptr);
    static MapLoader *m_pThis;
};

#endif // MAPLOADER_H
