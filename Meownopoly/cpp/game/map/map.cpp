#include "map.h"
#include "mapfilemanager.h"
#include "maptypes.h"

#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonValue>
#include <QHash>
#include <QStringList>
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
        is->setParent(this);   // Level 3 — parent-child Qt : Map gère la
                               // cleanup des tuiles à sa destruction.
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
    // Level 3 — plus de delete manuel : mapInfo et toutes les tuiles
    // (m_tiles + m_pendingDestroy) sont des QObject-children de `this`
    // (cf. setParent dans Map::Map/addTile/setMapInfo). QObject::~QObject
    // les détruit automatiquement. On vide juste les listes pour éviter
    // qu'un utilisateur extérieur n'observe des pointeurs invalides.
    m_tiles.clear();
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
    map->setSourceType(mapType);

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
    // Level 3 — garantit parent-child. Les appelants qui allouent
    // directement une ItemSnapable (ex: Map::applyDelta TileAdded) ne
    // mettent pas toujours setParent ; on le fait ici pour homogénéiser.
    tile->setParent(this);
    m_tiles.append(tile);
    updateTileCounts();
    emit tileAddedToMap(tile);
}

void Map::removeTile(const QUuid &tileId)
{
    for (int i = 0; i < m_tiles.size(); ++i) {
        if (m_tiles[i]->uniqueId() == tileId) {
            ItemSnapable *t = m_tiles[i];
            const int type = static_cast<int>(t->tileType());
            m_tiles.removeAt(i);
            updateTileCounts();
            m_pendingDestroy.append(t);
            emit tileRemovedFromMap(tileId, type);
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
        qDebug() << "[Map] applyDelta TileModified uuid=" << delta.tileId.toString()
                 << " tile=" << (tile ? "found" : "NULL (m_tiles size=" + QString::number(m_tiles.size()) + ")");
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

// ---- D28 (T3-4) : undo/redo ciblé d'une proposition durable ----

namespace {

// Découpe une entrée de write-set "<uuid>/<seg>/<seg>…" en (uuid, [seg…]).
// Les segments désignent un chemin DANS l'objet `memory` de la tuile (doc 05 :
// namespaces `config`/`state` sous `memory`). Retourne false si la forme est
// invalide (uuid manquant/nul ou aucune clé).
bool splitWriteSetEntry(const QString &entry, QUuid *uuidOut, QStringList *pathOut)
{
    const QStringList parts = entry.split(QLatin1Char('/'), Qt::SkipEmptyParts);
    if (parts.size() < 2) return false;
    const QUuid u(parts.first());
    if (u.isNull()) return false;
    *uuidOut = u;
    // Chemin réel dans la tuile : sous l'objet `memory`.
    QStringList path;
    path << QStringLiteral("memory");
    path += parts.mid(1);
    *pathOut = path;
    return true;
}

// Lecture d'un chemin imbriqué. `found` distingue absent de présent-mais-null.
QJsonValue jsonAtPath(const QJsonObject &root, const QStringList &path, bool *found)
{
    QJsonValue cur = QJsonValue(root);
    for (const QString &seg : path) {
        if (!cur.isObject()) { if (found) *found = false; return {}; }
        const QJsonObject o = cur.toObject();
        if (!o.contains(seg)) { if (found) *found = false; return {}; }
        cur = o.value(seg);
    }
    if (found) *found = true;
    return cur;
}

// Écrit (ou retire si `remove`) une valeur à un chemin imbriqué, en créant les
// objets intermédiaires au besoin. Retourne le root modifié (copie).
QJsonObject jsonSetPath(QJsonObject root, const QStringList &path,
                        const QJsonValue &val, bool remove)
{
    if (path.isEmpty()) return root;
    if (path.size() == 1) {
        if (remove) root.remove(path.first());
        else        root.insert(path.first(), val);
        return root;
    }
    QJsonObject child = root.value(path.first()).toObject();
    child = jsonSetPath(child, path.mid(1), val, remove);
    root.insert(path.first(), child);
    return root;
}

} // namespace

void Map::applyTargetedGroup(const QList<EditDelta> &group, bool useBefore,
                             const QStringList &writeSet,
                             QList<EditDelta> *appliedOut, QSet<QUuid> &touched)
{
    // Baselines par tuile : `before` du PREMIER delta (état pré-transaction)
    // et `after` du DERNIER (état visé par la proposition). L'undo restaure le
    // premier, le redo ré-applique le dernier.
    QHash<QUuid, QJsonObject> firstBefore;
    QHash<QUuid, QJsonObject> lastAfter;
    for (const EditDelta &d : group) {
        if (d.type != EditDeltaType::TileModified) continue;
        if (!firstBefore.contains(d.tileId)) firstBefore.insert(d.tileId, d.before);
        lastAfter.insert(d.tileId, d.after);
    }

    const QUuid gid = group.isEmpty() ? QUuid() : group.first().groupId;

    // 1) Deltas STRUCTURELS inversés/rejoués en totalité (l'artefact créé est
    //    retiré à l'undo, D15 ; restauré au redo). Sens d'itération cohérent
    //    avec les dépendances de liens : inverse pour l'undo, normal pour redo.
    auto handleStructural = [&](const EditDelta &d) {
        switch (d.type) {
        case EditDeltaType::TileAdded:
            applyDelta(d, useBefore, touched);
            if (appliedOut) {
                if (useBefore) // undo add → suppression rediffusée
                    appliedOut->append({ EditDeltaType::TileDeleted, d.tileId,
                                         gid, {}, {} });
                else           // redo add → ré-ajout rediffusé
                    appliedOut->append({ EditDeltaType::TileAdded, d.tileId,
                                         gid, {}, d.after });
            }
            break;
        case EditDeltaType::TileDeleted:
            applyDelta(d, useBefore, touched);
            if (appliedOut) {
                if (useBefore) // undo delete → restauration rediffusée (payload `before`)
                    appliedOut->append({ EditDeltaType::TileAdded, d.tileId,
                                         gid, {}, d.before });
                else           // redo delete → suppression rediffusée
                    appliedOut->append({ EditDeltaType::TileDeleted, d.tileId,
                                         gid, {}, {} });
            }
            break;
        case EditDeltaType::MetadataChanged:
            applyDelta(d, useBefore, touched);
            if (appliedOut)
                appliedOut->append({ EditDeltaType::MetadataChanged, {}, gid,
                                     {}, useBefore ? d.before : d.after });
            break;
        case EditDeltaType::TileModified:
            break; // traité ciblé plus bas
        }
    };
    if (useBefore)
        for (auto it = group.crbegin(); it != group.crend(); ++it) handleStructural(*it);
    else
        for (const EditDelta &d : group) handleStructural(d);

    // 2) Deltas TileModified : restauration CIBLÉE, fusionnée dans l'état
    //    COURANT de la tuile (LWW — D28 « restaure malgré tout »).
    for (auto it = firstBefore.constBegin(); it != firstBefore.constEnd(); ++it) {
        const QUuid tid = it.key();
        ItemSnapable *tile = tileById(tid);
        if (!tile) continue; // tuile retirée entre-temps : rien à restaurer

        const QJsonObject source = useBefore ? firstBefore.value(tid)
                                             : lastAfter.value(tid);

        // Chemins effectifs à restaurer :
        //  - si la proposition a DÉCLARÉ un write-set pour cette tuile, on fait
        //    strictement confiance à cette déclaration (granularité fine sous
        //    `memory`, jamais de snapshot global — D28) ;
        //  - sinon, repli sur les clés de PREMIER niveau qui ont changé entre
        //    le `before` et le `after` (couvre move/resize/config non déclarés),
        //    ce qui reste ciblé (jamais toute la tuile).
        QList<QStringList> paths;
        for (const QString &entry : writeSet) {
            QUuid u; QStringList p;
            if (!splitWriteSetEntry(entry, &u, &p)) continue;
            if (u == tid) paths.append(p);
        }
        if (paths.isEmpty()) {
            const QJsonObject before = firstBefore.value(tid);
            const QJsonObject after  = lastAfter.value(tid);
            QStringList keys = before.keys();
            for (const QString &k : after.keys())
                if (!keys.contains(k)) keys.append(k);
            for (const QString &k : keys)
                if (before.value(k) != after.value(k))
                    paths.append(QStringList{ k });
        }
        if (paths.isEmpty()) continue;

        QJsonObject merged =
            QJsonDocument::fromJson(tile->toJSON().toUtf8()).object();
        for (const QStringList &path : paths) {
            bool had = false;
            const QJsonValue v = jsonAtPath(source, path, &had);
            merged = jsonSetPath(merged, path, v, /*remove=*/!had);
        }

        tile->applyJson(merged);
        rewireLinks(tile, merged, touched);
        tile->commitCurrentState();
        touched.insert(tid);
        if (appliedOut)
            appliedOut->append({ EditDeltaType::TileModified, tid, gid, {}, merged });
    }
}

// Extrait du sommet `stack` tous les deltas de `groupId` (où qu'ils soient),
// dans l'ordre d'application (bas → haut), en ré-empilant le reste tel quel.
static QList<EditDelta> extractGroupFromStack(QStack<EditDelta> &stack,
                                              const QUuid &groupId)
{
    QList<EditDelta> all;      // bas → haut
    while (!stack.isEmpty()) all.prepend(stack.pop());
    QList<EditDelta> group;
    for (const EditDelta &d : all) {
        if (d.groupId == groupId) group.append(d);
        else                      stack.push(d);
    }
    return group;
}

bool Map::undoTargetedGroup(const QUuid &groupId, const QStringList &writeSet,
                            QList<EditDelta> *appliedOut, QString *reasonOut)
{
    if (groupId.isNull()) {
        if (reasonOut) *reasonOut = QStringLiteral("groupId nul");
        return false;
    }

    QList<EditDelta> group = extractGroupFromStack(m_undoStack, groupId);
    if (group.isEmpty()) {
        if (reasonOut)
            *reasonOut = QStringLiteral("groupe %1 absent de la pile d'undo")
                             .arg(groupId.toString());
        return false;
    }

    m_isRestoringState = true;
    emit canSaveChanged();

    QSet<QUuid> touched;
    applyTargetedGroup(group, /*useBefore=*/true, writeSet, appliedOut, touched);

    // Le groupe passe sur la pile de redo (ordre bas → haut préservé).
    for (const EditDelta &d : group) m_redoStack.push(d);

    m_isRestoringState = false;
    emit canSaveChanged();
    emit forceUnselectAll();
    emit afterRestoration(touched.values());

    qInfo().noquote() << "[D28] undo ciblé — groupe" << groupId.toString()
                      << "—" << writeSet.size() << "clé(s) déclarée(s),"
                      << group.size() << "delta(s), " << touched.size()
                      << "tuile(s) touchée(s)";
    return true;
}

bool Map::redoTargetedGroup(const QUuid &groupId, const QStringList &writeSet,
                            QList<EditDelta> *appliedOut, QString *reasonOut)
{
    if (groupId.isNull()) {
        if (reasonOut) *reasonOut = QStringLiteral("groupId nul");
        return false;
    }

    QList<EditDelta> group = extractGroupFromStack(m_redoStack, groupId);
    if (group.isEmpty()) {
        if (reasonOut)
            *reasonOut = QStringLiteral("groupe %1 absent de la pile de redo")
                             .arg(groupId.toString());
        return false;
    }

    m_isRestoringState = true;
    emit canSaveChanged();

    QSet<QUuid> touched;
    applyTargetedGroup(group, /*useBefore=*/false, writeSet, appliedOut, touched);

    for (const EditDelta &d : group) m_undoStack.push(d);

    m_isRestoringState = false;
    emit canSaveChanged();
    emit forceUnselectAll();
    emit afterRestoration(touched.values());

    qInfo().noquote() << "[D28] redo ciblé (provisoire) — groupe"
                      << groupId.toString() << "—" << group.size() << "delta(s)";
    return true;
}
