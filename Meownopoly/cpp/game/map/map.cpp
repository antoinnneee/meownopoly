#include "map.h"
#include "mapfilemanager.h"
#include "maptypes.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QHash>
#include <QDebug>
#include <QQmlEngine>

Map::Map(QObject *parent) : QObject(parent)
{
}

Map::Map(QJsonObject jsonObject, QObject *parent) : QObject(parent)
{
    if (!jsonObject.contains("snapableTiles") || !jsonObject["snapableTiles"].isArray()) {
        qWarning() << "MAP_LOADING: Clé 'snapableTiles' manquante ou invalide dans le JSON de la map";
        return;
    }

    QJsonArray snapableTilesArray = jsonObject["snapableTiles"].toArray();

    for (int i = 0; i < snapableTilesArray.size(); ++i) {
        if (!snapableTilesArray[i].isObject()) {
            qWarning() << "MAP_LOADING: Entrée snapableTiles[" << i << "] n'est pas un objet JSON - ignorée";
            continue;
        }
        const QJsonObject tileObject = snapableTilesArray[i].toObject();

        if (!tileObject.contains("uniqueId") || !tileObject.contains("tileType")) {
            qWarning() << "MAP_LOADING: Tile[" << i << "] sans uniqueId ou tileType - ignorée";
            continue;
        }

        ItemSnapable *is = new ItemSnapable(tileObject);
        QQmlEngine::setObjectOwnership(is, QQmlEngine::CppOwnership);
        m_tiles.append(is);
    }
    updateTileCounts();

    // Index UUID → tile pour une résolution O(1) des liens
    QHash<QString, ItemSnapable*> tileIndex;
    for (ItemSnapable *tile : std::as_const(m_tiles)) {
        QString id = tile->uniqueId().toString();
        if (tileIndex.contains(id)) {
            qWarning() << "MAP_LOADING: UUID dupliqué détecté:" << id << "- seule la dernière tile sera référencée";
        }
        tileIndex[id] = tile;
    }

    for (ItemSnapable *is : std::as_const(m_tiles)) {
        QJsonObject originalJson = is->getOriginalJson();
        QJsonArray nextIdArray = originalJson["next"].toArray();

        for (const QJsonValueRef value : nextIdArray) {
            QString nextId = value.toString();
            if (nextId.isEmpty()) {
                qWarning() << "MAP_LOADING: UUID vide dans next[] de la tile" << is->uniqueId().toString();
                continue;
            }
            ItemSnapable *targetTile = tileIndex.value(nextId, nullptr);
            if (targetTile) {
                is->addNext(targetTile);
                targetTile->addPrev(is);
            } else {
                qWarning() << "MAP_LOADING: Référence next invalide:" << nextId
                           << "depuis la tile" << is->uniqueId().toString()
                           << "- connexion ignorée";
            }
        }
    }
}

Map::~Map()
{
    if (mapInfo) {
        delete mapInfo;
        mapInfo = nullptr;
    }
    for (int i = 0; i < m_tiles.size(); i++){
        delete m_tiles.at(i);
    }
    m_tiles.clear();
    // Les tiles stashées en attente de destruction (déjà retirées de m_tiles)
    for (ItemSnapable *t : std::as_const(m_pendingDestroy))
        delete t;
    m_pendingDestroy.clear();
}


MapInfo *Map::getMapInfo() const
{
    return mapInfo;
}

void Map::setMapInfo(MapInfo *newMapInfo)
{
    if (mapInfo == newMapInfo)
        return;
    if (mapInfo)
        mapInfo->deleteLater();
    mapInfo = newMapInfo;
    if (newMapInfo)
        newMapInfo->setParent(this);
    emit mapInfoChanged();
}

QList<ItemSnapable *> Map::tiles() const
{
    return m_tiles;
}

void Map::setTiles(const QList<ItemSnapable *> &newTiles)
{
    m_tiles = newTiles;
    updateTileCounts();
}

void Map::updateTileCounts()
{
    int caseCount = 0;
    int decorationCount = 0;
    int zoneCount = 0;
    for (ItemSnapable *tile : std::as_const(m_tiles)) {
        switch (tile->tileType()) {
        case ItemSnapable::CaseTile:
            ++caseCount;
            break;
        case ItemSnapable::DecorationTile:
            ++decorationCount;
            break;
        case ItemSnapable::PhysicZoneTile:
            ++zoneCount;
            break;
        default:
            break;
        }
    }
    if (m_caseTileCount != caseCount) {
        m_caseTileCount = caseCount;
        emit caseTileCountChanged();
    }
    if (m_decorationTileCount != decorationCount) {
        m_decorationTileCount = decorationCount;
        emit decorationTileCountChanged();
    }
    if (m_zoneTileCount != zoneCount) {
        m_zoneTileCount = zoneCount;
        emit zoneTileCountChanged();
    }
}

Map *Map::loadMap(QJsonObject newEdit)
{
    QJsonObject jsonObject = newEdit;
    Map *map = new Map(jsonObject);

    if (jsonObject.contains("mapInfo") && jsonObject["mapInfo"].isObject()) {
        QJsonObject mapInfoObject = jsonObject["mapInfo"].toObject();
        MapInfo *mapInfo = new MapInfo(mapInfoObject);
        map->setMapInfo(mapInfo);
    } else {
        qWarning() << "MAP_LOADING: Clé 'mapInfo' manquante ou invalide - map chargée sans métadonnées";
    }

    return map;
}

Map *Map::loadMap(QString mapName, MapTypes::MapType mapType)
{
    QJsonObject jsonObject;
    switch (mapType){
    case MapTypes::AUTOSAVE:
    case MapTypes::CUSTOM:
        jsonObject = MapFileManager::readMapFile(mapName, mapType);
        if (jsonObject.isEmpty()) {
            qDebug() << "Failed to read map file:" << mapName;
            return nullptr;
        }
        break;
    default:
        break;
    }

    Map *map = new Map(jsonObject);

    if (jsonObject.contains("mapInfo") && jsonObject["mapInfo"].isObject()) {
        QJsonObject mapInfoObject = jsonObject["mapInfo"].toObject();
        MapInfo *mapInfo = new MapInfo(mapInfoObject);
        map->setMapInfo(mapInfo);
    } else {
        qWarning() << "MAP_LOADING: Clé 'mapInfo' manquante ou invalide - map chargée sans métadonnées";
    }

    return map;
}

// ---- Undo/redo delta ----

void Map::pushDelta(const EditDelta &delta)
{
    m_undoStack.push(delta);
    m_redoStack.clear();
}

void Map::clearHistory()
{
    m_undoStack.clear();
    m_redoStack.clear();
}

ItemSnapable* Map::tileById(const QUuid &id) const
{
    for (ItemSnapable *tile : m_tiles) {
        if (tile->uniqueId() == id)
            return tile;
    }
    return nullptr;
}

void Map::addTile(ItemSnapable* tile)
{
    if (!tile) return;
    m_tiles.append(tile);
    updateTileCounts();
}

void Map::removeTile(const QUuid &tileId)
{
    for (int i = 0; i < m_tiles.size(); ++i) {
        if (m_tiles[i]->uniqueId() == tileId) {
            ItemSnapable *t = m_tiles[i];
            m_tiles.removeAt(i);
            updateTileCounts();
            m_pendingDestroy.append(t);
            return;
        }
    }
}

void Map::finalizeTile(const QUuid &tileId)
{
    for (int i = 0; i < m_pendingDestroy.size(); ++i) {
        if (m_pendingDestroy[i]->uniqueId() == tileId) {
            m_pendingDestroy[i]->deleteLater();
            m_pendingDestroy.removeAt(i);
            return;
        }
    }
}

// Retire `tile` des listes next/prev de ses voisins et vide ses propres listes.
void Map::unwireLinks(ItemSnapable *tile, QSet<QUuid> &touchedOut)
{
    if (!tile) return;
    touchedOut.insert(tile->uniqueId());

    const QList<ItemSnapable*> oldNext = tile->next;
    const QList<ItemSnapable*> oldPrev = tile->prev;
    for (ItemSnapable *n : oldNext) {
        if (n) {
            n->removePrev(tile);
            touchedOut.insert(n->uniqueId());
        }
    }
    for (ItemSnapable *p : oldPrev) {
        if (p) {
            p->removeNext(tile);
            touchedOut.insert(p->uniqueId());
        }
    }
    tile->next.clear();
    tile->prev.clear();
}

// Réinitialise les liens de `tile` à partir de `json` (champs "next"/"prev").
// Maintien de la symétrie : chaque voisin voit aussi sa liste inverse mise à jour.
void Map::rewireLinks(ItemSnapable *tile, const QJsonObject &json, QSet<QUuid> &touchedOut)
{
    if (!tile) return;
    unwireLinks(tile, touchedOut);

    QJsonArray nextIds = json["next"].toArray();
    for (const QJsonValueRef v : nextIds) {
        ItemSnapable *t = tileById(QUuid(v.toString()));
        if (!t) continue;
        if (!tile->next.contains(t)) tile->addNext(t);
        if (!t->prev.contains(tile)) t->addPrev(tile);
        touchedOut.insert(t->uniqueId());
    }
    QJsonArray prevIds = json["prev"].toArray();
    for ( QJsonValueRef v : prevIds) {
        ItemSnapable *s = tileById(QUuid(v.toString()));
        if (!s) continue;
        if (!tile->prev.contains(s)) tile->addPrev(s);
        if (!s->next.contains(tile)) s->addNext(tile);
        touchedOut.insert(s->uniqueId());
    }
}

void Map::applyDelta(const EditDelta &delta, bool applyBefore, QSet<QUuid> &touchedOut)
{
    const QJsonObject &jsonState = applyBefore ? delta.before : delta.after;

    switch (delta.type) {
    case EditDeltaType::TileModified: {
        ItemSnapable *tile = tileById(delta.tileId);
        if (tile) {
            tile->applyJson(jsonState);
            rewireLinks(tile, jsonState, touchedOut);
            tile->commitCurrentState();
        }
        break;
    }
    case EditDeltaType::TileAdded: {
        if (applyBefore) {
            // undo addition = remove the tile (idempotent si déjà retirée par remote)
            ItemSnapable *toDelete = tileById(delta.tileId);
            if (!toDelete) break;
            unwireLinks(toDelete, touchedOut);
            removeTile(delta.tileId);
            emit tileRemovedFromHistory(delta.tileId);
            finalizeTile(delta.tileId);
        } else {
            // redo addition = re-add the tile (idempotent si recréée par remote)
            if (tileById(delta.tileId)) break;
            ItemSnapable *tile = new ItemSnapable(jsonState);
            QQmlEngine::setObjectOwnership(tile, QQmlEngine::CppOwnership);
            addTile(tile);
            rewireLinks(tile, jsonState, touchedOut);
            tile->commitCurrentState();
            emit tileRestoredFromHistory(tile);
        }
        break;
    }
    case EditDeltaType::TileDeleted: {
        if (applyBefore) {
            // undo deletion = restore the tile (idempotent si déjà restaurée par remote)
            if (tileById(delta.tileId)) break;
            ItemSnapable *tile = new ItemSnapable(jsonState);
            QQmlEngine::setObjectOwnership(tile, QQmlEngine::CppOwnership);
            addTile(tile);
            rewireLinks(tile, jsonState, touchedOut);
            tile->commitCurrentState();
            emit tileRestoredFromHistory(tile);
        } else {
            // redo deletion = remove again (idempotent si déjà retirée par remote)
            ItemSnapable *toDelete = tileById(delta.tileId);
            if (!toDelete) break;
            unwireLinks(toDelete, touchedOut);
            removeTile(delta.tileId);
            emit tileRemovedFromHistory(delta.tileId);
            finalizeTile(delta.tileId);
        }
        break;
    }
    case EditDeltaType::MetadataChanged: {
        if (mapInfo) {
            MapInfo *mi = new MapInfo(jsonState);
            setMapInfo(mi);
        }
        break;
    }
    }
}

bool Map::undo(){
    m_lastRevertedBatch.clear();
    m_lastRevertedWasUndo = true;
    if (m_undoStack.isEmpty())
        return false;

    m_isRestoringState = true;
    emit canSaveChanged();

    QUuid groupId = m_undoStack.top().groupId;
    QList<EditDelta> group;
    while   (!m_undoStack.isEmpty() &&((groupId.isNull() && group.isEmpty()) ||
            (!groupId.isNull() && m_undoStack.top().groupId == groupId))) {

        group.prepend(m_undoStack.pop());
    }

    m_isRestoringState = false;
    emit forceUnselectAll();
    emit canSaveChanged();

    QSet<QUuid> touched;
    for (const EditDelta &delta : group) {
        applyDelta(delta, true, touched);
        m_redoStack.push(delta);
    }
    m_lastRevertedBatch = group;
    emit afterRestoration(touched.values());
    return true;
}

bool Map::redo()
{
    m_lastRevertedBatch.clear();
    m_lastRevertedWasUndo = false;
    if (m_redoStack.isEmpty())
        return false;

    m_isRestoringState = true;
    emit canSaveChanged();

    QUuid groupId = m_redoStack.top().groupId;
    QList<EditDelta> group;
    while (!m_redoStack.isEmpty() &&
           ((groupId.isNull() && group.isEmpty()) ||
            (!groupId.isNull() && m_redoStack.top().groupId == groupId))) {
        group.prepend(m_redoStack.pop());
    }

    m_isRestoringState = false;
    emit canSaveChanged();
    emit forceUnselectAll();

    QSet<QUuid> touched;
    for (const EditDelta &delta : group) {
        applyDelta(delta, false, touched);
        m_undoStack.push(delta);
    }
    m_lastRevertedBatch = group;
    emit afterRestoration(touched.values());
    return true;
}
