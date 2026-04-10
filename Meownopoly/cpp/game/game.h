#ifndef GAME_H
#define GAME_H

#include <QObject>
#include <QQmlEngine>
#include <QVector>
#include <QList>
#include <QVariant>
#include <QDir>
#include <QJsonArray>
#include <QJsonObject>

#include "game/item_snapable/ItemSnapable.h"
#include "map/mapinfo.h"
#include "map/map.h"
#include "map/maptypes.h"
#include "map/undoredomanager.h"


class Game : public QObject
{
    Q_OBJECT

public:

    enum GAME_CONDITION {
        ABANDON,
        BANKRUPT,
        CTN_TURN
    };

    static void registerQml();
    static Game *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    Q_INVOKABLE void startGame();

    // Map saving/loading

    DisplayParameter *getDisplayerParameter(const QVariantMap &displayInfoMap);
    QJsonArray formatTileDataToJson(ItemSnapable &is, QJsonArray snapableTilesArray);

    Q_INVOKABLE bool saveMap(MapInfo* mapInfo, QVariantList itemSnapableList, MapTypes::MapType mapType);
    bool compareMap(const QVariantList& itemSnapableList, const QJsonObject& newJsonState);
    Q_INVOKABLE bool deleteMap(QString mapName, MapTypes::MapType mapType);
    Q_INVOKABLE Map *loadMap(QString mapName, MapTypes::MapType mapType);

    Q_INVOKABLE QList<ItemSnapable*> generateItems(QJsonObject jsonObject);


    Q_INVOKABLE void askPreview();
    Q_INVOKABLE void askNext();

    // Template saving/loading
    Q_INVOKABLE bool saveTemplate(QString name, QJsonArray elementsJson);
    Q_INVOKABLE bool deleteTemplate(QString name);
    Q_INVOKABLE QJsonObject loadTemplate(QString name);
    Q_INVOKABLE QJsonArray getTemplateElementsForPlacement(QString name, int targetX, int targetY);


    ~Game();

public slots:
    void onReturnEdit(QJsonObject newEdit);

signals:
    void gameStarted();

    void clearCurrentMap();

    void mapLoaded(Map *map);
    void foundItemSnapableTile(ItemSnapable *itemSnapable);
    void updateListEdits(QJsonObject newEdit);
    void askEdit(UndoRedoManager::EditAction editAction);

private:
    explicit Game(QObject *parent = nullptr);
    static Game *m_pThis;
};

#endif // GAME_H
