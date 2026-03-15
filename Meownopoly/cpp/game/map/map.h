#ifndef MAP_H
#define MAP_H

#include <QObject>
#include <QStack>
#include "mapinfo.h"
#include "editdelta.h"
#include "game/item_snapable/ItemSnapable.h"
#include "maptypes.h"

class Map : public QObject
{
    Q_OBJECT

    Q_PROPERTY(int caseTileCount READ caseTileCount NOTIFY caseTileCountChanged FINAL)
    Q_PROPERTY(int decorationTileCount READ decorationTileCount NOTIFY decorationTileCountChanged FINAL)
    Q_PROPERTY(int zoneTileCount READ zoneTileCount NOTIFY zoneTileCountChanged FINAL)

    Q_PROPERTY(MapInfo *mapInfo READ getMapInfo WRITE setMapInfo NOTIFY mapInfoChanged FINAL)
    Q_PROPERTY(bool canSave READ canSave NOTIFY canSaveChanged FINAL)

public:
    Map(QObject *parent = nullptr);
    Map(QJsonObject jsonObject, QObject *parent = nullptr);

    ~Map();

    int caseTileCount() const { return m_caseTileCount; }
    int decorationTileCount() const { return m_decorationTileCount; }
    int zoneTileCount() const { return m_zoneTileCount; }

    MapInfo *getMapInfo() const;
    void setMapInfo(MapInfo *newMapInfo);

    QList<ItemSnapable *> tiles() const;
    void setTiles(const QList<ItemSnapable *> &newTiles);

    static Map* loadMap(QJsonObject newEdit);
    static Map* loadMap(QString mapName, MapTypes::MapType mapType);

    // ---- Undo/redo delta API ----
    void pushDelta(const EditDelta &delta);
    bool undo();
    bool redo();
    bool canSave() const { return !m_isRestoringState; }

    void clearHistory();

    ItemSnapable* tileById(const QUuid &id) const;
    void addTile(ItemSnapable* tile);
    void removeTile(const QUuid &tileId);

    void applyDelta(const EditDelta &delta, bool applyBefore);

    void updateTileCounts();


signals:
    void caseTileCountChanged();
    void decorationTileCountChanged();
    void zoneTileCountChanged();
    void mapInfoChanged();
    void canSaveChanged();

    void mapLoaded(Map *map);
    void foundItemSnapableTile(ItemSnapable *itemSnapable);

    // Emitted by undo/redo to let Game relay to QML
    void tileRemovedFromHistory(QUuid tileId);
    void tileRestoredFromHistory(ItemSnapable *tile);
    void forceUnselectAll();

private:

    QList<ItemSnapable*> m_tiles;
    int m_caseTileCount = 0;
    int m_decorationTileCount = 0;
    int m_zoneTileCount = 0;

    MapInfo *mapInfo = nullptr;

    QStack<EditDelta> m_undoStack;
    QStack<EditDelta> m_redoStack;
    bool m_isRestoringState = false;
};

#endif // MAP_H
