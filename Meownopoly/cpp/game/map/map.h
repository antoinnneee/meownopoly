#ifndef MAP_H
#define MAP_H

#include <QObject>
#include <QStack>
#include <QSet>
#include <QUuid>
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

    // Deltas traités lors du dernier undo()/redo(). Peuplés à chaque appel.
    // Utilisé par Game::askPreview/askNext pour broadcaster les ops inverses
    // (Pattern B en mode collab).
    QList<EditDelta> lastRevertedBatch() const { return m_lastRevertedBatch; }
    bool lastRevertedWasUndo() const { return m_lastRevertedWasUndo; }

    void clearHistory();

    ItemSnapable* tileById(const QUuid &id) const;
    void addTile(ItemSnapable* tile);
    void removeTile(const QUuid &tileId);        // stashe dans m_pendingDestroy
    void finalizeTile(const QUuid &tileId);      // deleteLater depuis m_pendingDestroy

    void applyDelta(const EditDelta &delta, bool applyBefore, QSet<QUuid> &touchedOut);

    // Link helpers (symmetriques)
    void unwireLinks(ItemSnapable *tile, QSet<QUuid> &touchedOut);
    void rewireLinks(ItemSnapable *tile, const QJsonObject &json, QSet<QUuid> &touchedOut);

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

    // Émis à la fin d'un batch undo/redo, contient les UUID des tiles dont
    // l'état (liens inclus) a été mis à jour. Le QML s'en sert pour
    // resynchroniser les connectionManager visuels.
    void afterRestoration(const QList<QUuid> &tileIds);

private:


    QList<ItemSnapable*> m_tiles;
    QList<ItemSnapable*> m_pendingDestroy;
    int m_caseTileCount = 0;
    int m_decorationTileCount = 0;
    int m_zoneTileCount = 0;

    MapInfo *mapInfo = nullptr;

    QStack<EditDelta> m_undoStack;
    QStack<EditDelta> m_redoStack;
    bool m_isRestoringState = false;

    QList<EditDelta> m_lastRevertedBatch;
    bool m_lastRevertedWasUndo = false;
};

#endif // MAP_H
