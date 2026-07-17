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

    // Origine du fichier (AUTOSAVE vs CUSTOM). Déterminée au load par
    // Map::loadMap(name, type). Utilisée par Game::saveCurrentMap pour
    // choisir le chemin de sérialisation. Ce n'est PAS une propriété du
    // contenu (MapInfo) mais de l'emplacement disque d'origine.
    MapTypes::MapType sourceType() const { return m_sourceType; }
    void setSourceType(MapTypes::MapType t) { m_sourceType = t; }

    QList<ItemSnapable *> tiles() const;
    void setTiles(const QList<ItemSnapable *> &newTiles);

    static Map* loadMap(QJsonObject newEdit);
    static Map* loadMap(QString mapName, MapTypes::MapType mapType);

    // ---- Undo/redo delta API ----
    void pushDelta(const EditDelta &delta);
    bool undo();
    bool redo();
    bool canSave() const { return !m_isRestoringState; }

    // ---- D28 (T3-4) : undo ciblé d'une proposition durable ----
    //
    // Contrairement à undo() (LIFO, restauration WHOLESALE du `before` de la
    // tuile), l'undo ciblé adresse un groupe `groupId` OÙ QU'IL SOIT dans la
    // pile et ne restaure QUE les clés déclarées par le write-set durable de
    // la proposition (chemins "<uuid>/<seg>/…" pointant dans l'objet `memory`
    // de la tuile). La restauration fusionne le `before` de la transaction
    // dans l'état COURANT de la tuile : les clés du write-set sont écrasées
    // (LWW, D28 « restaure malgré tout » une modif concurrente), les autres
    // clés — potentiellement modifiées entre-temps par un pair — sont
    // préservées. Les deltas STRUCTURELS du groupe (TileAdded/TileDeleted)
    // sont eux inversés en totalité (l'artefact créé est retiré, D15).
    //
    // `appliedOut` (optionnel) reçoit les deltas RÉSULTANTS (état final par
    // tuile) pour rediffusion aux pairs en collab. Le groupe est déplacé vers
    // la pile de redo. Retourne false (avec `reasonOut`) si le groupe est
    // absent de la pile d'undo.
    //
    // Comportement du redo : PROVISOIRE (doc 08 §8, « à trancher »). Le redo
    // ré-applique les valeurs `after` du write-set (LWW à nouveau) — voir
    // redoTargetedGroup.
    bool undoTargetedGroup(const QUuid &groupId, const QStringList &writeSet,
                           QList<EditDelta> *appliedOut = nullptr,
                           QString *reasonOut = nullptr);
    bool redoTargetedGroup(const QUuid &groupId, const QStringList &writeSet,
                           QList<EditDelta> *appliedOut = nullptr,
                           QString *reasonOut = nullptr);

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

    // Phase 3 — flux unifié de "vie" des tuiles, consommé par
    // ItemSnapableEvents : couvre toutes les voies d'entrée (load fichier,
    // Game::updateMap, applyDelta undo/redo, applyRemoteDelta collab).
    // tileType est l'int de ItemSnapable::TileType (la valeur n'est pas
    // accessible une fois la tile détruite, donc on la transporte au moment
    // de la suppression).
    void tileAddedToMap(ItemSnapable *tile);
    void tileRemovedFromMap(QUuid tileId, int tileType);

    // Emitted by undo/redo to let Game relay to QML
    void tileRemovedFromHistory(QUuid tileId);
    void tileRestoredFromHistory(ItemSnapable *tile);
    void forceUnselectAll();

    // Émis à la fin d'un batch undo/redo, contient les UUID des tiles dont
    // l'état (liens inclus) a été mis à jour. Le QML s'en sert pour
    // resynchroniser les connectionManager visuels.
    void afterRestoration(const QList<QUuid> &tileIds);

private:

    // D28 (T3-4) — cœur partagé undo/redo ciblé : applique un groupe de deltas
    // en restauration ciblée. `useBefore` = sens (undo restaure `before`, redo
    // ré-applique `after`). Structurels inversés en totalité, TileModified
    // fusionnés clé-par-clé (write-set) dans l'état courant.
    void applyTargetedGroup(const QList<EditDelta> &group, bool useBefore,
                            const QStringList &writeSet,
                            QList<EditDelta> *appliedOut, QSet<QUuid> &touched);

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

    // Default CUSTOM : toute Map non explicitement chargée depuis un autosave
    // est traitée comme custom (c.-à-d. écrite sous <mapName>_map.json). Les
    // deux branches de loadMap peuvent l'écraser au besoin.
    MapTypes::MapType m_sourceType = MapTypes::CUSTOM;
};

#endif // MAP_H
