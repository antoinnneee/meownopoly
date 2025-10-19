#ifndef MAPLOADER_H
#define MAPLOADER_H

#include <QObject>
#include <QQmlEngine>
#include "map/map.h"
#include "tools/undoredomanager.h"

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

signals:
    void mapLoaded(Map *map);
    void foundItemSnapableTile(ItemSnapable *itemSnapable);

    void updateListEdits(QJsonObject newEdit);
    void askEdit(UndoRedoManager::EditAction editAction);

public slots:

    void onReturnEdit(QJsonObject newEdit);

private:
    explicit MapLoader(QObject *parent = nullptr);
    static MapLoader *m_pThis;
};

#endif // MAPLOADER_H
