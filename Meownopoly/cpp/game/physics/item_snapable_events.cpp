#include "item_snapable_events.h"

#include "game/item_snapable/Displayparameter.h"
#include "game/item_snapable/ItemSnapable.h"
#include "game/item_snapable/ZoneParameter.h"
#include "game/item_snapable/physicalobjectparameter.h"
#include "game/map/map.h"
#include "game/map/mapfilemanager.h"

#include <QVariant>
#include <QtQml>

ItemSnapableEvents *ItemSnapableEvents::m_instance = nullptr;

ItemSnapableEvents *ItemSnapableEvents::instance()
{
    if (!m_instance) m_instance = new ItemSnapableEvents();
    return m_instance;
}

QObject *ItemSnapableEvents::qmlInstance(QQmlEngine *, QJSEngine *)
{
    return ItemSnapableEvents::instance();
}

void ItemSnapableEvents::registerQml()
{
    qmlRegisterSingletonType<ItemSnapableEvents>(
        "Pattounx", 1, 0, "ItemSnapableEvents",
        &ItemSnapableEvents::qmlInstance);
}

ItemSnapableEvents::ItemSnapableEvents(QObject *parent)
    : QObject(parent)
{
    MapFileManager *mfm = MapFileManager::instance();
    if (mfm) {
        connect(mfm, &MapFileManager::currentMapChanged,
                this, &ItemSnapableEvents::onCurrentMapChanged);
        // Map déjà active au moment du registerQml ? Adopter direct.
        if (mfm->getCurrentMap()) attachMap(mfm->getCurrentMap());
    }
}

QVariantList ItemSnapableEvents::currentTiles() const
{
    QVariantList out;
    if (!m_map) return out;
    const auto tiles = m_map->tiles();
    out.reserve(tiles.size());
    for (ItemSnapable *t : tiles) {
        if (t) out.append(QVariant::fromValue<QObject *>(t));
    }
    return out;
}

void ItemSnapableEvents::onCurrentMapChanged()
{
    Map *next = MapFileManager::instance() ? MapFileManager::instance()->getCurrentMap() : nullptr;
    if (m_map.data() == next) return;

    if (m_map) detachMap(m_map.data(), /*emitDeletedForAllTiles=*/true);
    if (next)  attachMap(next);
}

void ItemSnapableEvents::attachMap(Map *map)
{
    if (!map) return;
    m_map = map;

    connect(map, &Map::tileAddedToMap,
            this, &ItemSnapableEvents::onTileAddedToMap);
    connect(map, &Map::tileRemovedFromMap,
            this, &ItemSnapableEvents::onTileRemovedFromMap);

    // Rétroactivité : map déjà peuplée (load disque, FullSync collab finie
    // avant qu'on adopte la map). Émettre tileCreated pour chaque tuile
    // existante et abonner les signaux de paramètres.
    for (ItemSnapable *tile : map->tiles()) {
        if (!tile) continue;
        attachTile(tile);
        emit tileCreated(tile);
    }
}

void ItemSnapableEvents::detachMap(Map *map, bool emitDeletedForAllTiles)
{
    if (!map) return;
    disconnect(map, nullptr, this, nullptr);

    // Notifier le détachement des tuiles encore vivantes côté ancienne map
    // pour que les consommateurs (bridge → physicsWorld) purgent leur état.
    const auto attached = m_attachedTiles;  // copie : detachTile mute le set
    for (ItemSnapable *tile : attached) {
        if (!tile) continue;
        if (emitDeletedForAllTiles)
            emit tileDeleted(tile->uniqueId(), static_cast<int>(tile->tileType()));
        detachTile(tile);
    }
    m_attachedTiles.clear();
    m_map.clear();
}

void ItemSnapableEvents::onTileAddedToMap(ItemSnapable *tile)
{
    if (!tile) return;
    attachTile(tile);
    emit tileCreated(tile);
}

void ItemSnapableEvents::onTileRemovedFromMap(const QUuid &tileId, int tileType)
{
    // Trouver la tile attachée correspondante (peut déjà être en pendingDestroy).
    ItemSnapable *match = nullptr;
    for (ItemSnapable *t : m_attachedTiles) {
        if (t && t->uniqueId() == tileId) { match = t; break; }
    }
    if (match) detachTile(match);
    emit tileDeleted(tileId, tileType);
}

void ItemSnapableEvents::attachTile(ItemSnapable *tile)
{
    if (!tile || m_attachedTiles.contains(tile)) return;
    m_attachedTiles.insert(tile);

    // Si la tile est détruite hors flow Map (ex: deleteLater post-finalize),
    // se désabonner pour éviter les pointeurs morts dans le set.
    connect(tile, &QObject::destroyed, this, [this, tile]() {
        m_attachedTiles.remove(tile);
    });

    // Mouvement / resize → tileMoved
    if (DisplayParameter *dp = tile->displayParameter()) {
        connect(dp, &DisplayParameter::gridRelativePositionXChanged,
                this, [this, tile]() { emit tileMoved(tile); });
        connect(dp, &DisplayParameter::gridRelativePositionYChanged,
                this, [this, tile]() { emit tileMoved(tile); });
        connect(dp, &DisplayParameter::unitSizeWidthChanged,
                this, [this, tile]() { emit tileMoved(tile); });
        connect(dp, &DisplayParameter::unitSizeHeightChanged,
                this, [this, tile]() { emit tileMoved(tile); });
    }

    // Mutations zone → zoneParameterChanged
    if (ZoneParameter *zp = tile->zoneParameter()) {
        auto bump = [this, tile]() { emit zoneParameterChanged(tile); };
        connect(zp, &ZoneParameter::polygonPointsChanged,        this, bump);
        connect(zp, &ZoneParameter::velocityDirectionChanged,    this, bump);
        connect(zp, &ZoneParameter::velocityStrenghtChanged,     this, bump);
        connect(zp, &ZoneParameter::frictionStrenghtChanged,     this, bump);
        connect(zp, &ZoneParameter::exclusionChanged,            this, bump);
        connect(zp, &ZoneParameter::speedMultiplierChanged,      this, bump);
        connect(zp, &ZoneParameter::accelerationMultiplierChanged, this, bump);
    }

    // Mutations objet physique → physicalObjectParameterChanged
    if (PhysicalObjectParameter *pop = tile->physicalObjectParameter()) {
        auto bump = [this, tile]() { emit physicalObjectParameterChanged(tile); };
        connect(pop, &PhysicalObjectParameter::massChanged,             this, bump);
        connect(pop, &PhysicalObjectParameter::bounceFactorChanged,     this, bump);
        connect(pop, &PhysicalObjectParameter::frictionStrengthChanged, this, bump);
        connect(pop, &PhysicalObjectParameter::linearDampingChanged,    this, bump);
    }
}

void ItemSnapableEvents::detachTile(ItemSnapable *tile)
{
    if (!tile) return;
    if (DisplayParameter *dp = tile->displayParameter()) disconnect(dp, nullptr, this, nullptr);
    if (ZoneParameter    *zp = tile->zoneParameter())    disconnect(zp, nullptr, this, nullptr);
    if (PhysicalObjectParameter *pop = tile->physicalObjectParameter()) disconnect(pop, nullptr, this, nullptr);
    disconnect(tile, &QObject::destroyed, this, nullptr);
    m_attachedTiles.remove(tile);
}
