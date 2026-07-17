#include "gameplay_event_ingest.h"

#include "gameplay_event_bus.h"

#include "game/game.h"
#include "game/item_snapable/Displayparameter.h"
#include "game/item_snapable/ItemSnapable.h"
#include "game/map/map.h"
#include "game/map/mapinfo.h"
#include "game/physics/item_snapable_events.h"
#include "game/physics/physics_session.h"

#include <QJsonObject>
#include <QUuid>
#include <QVariantMap>

namespace {

// Charge utile compacte décrivant une tuile (uuid + type + emprise grille).
QJsonObject tilePayload(ItemSnapable *tile)
{
    QJsonObject p;
    if (!tile) return p;
    p[QStringLiteral("uuid")]     = tile->uniqueId().toString(QUuid::WithoutBraces);
    p[QStringLiteral("tileType")] = static_cast<int>(tile->tileType());
    if (DisplayParameter *dp = tile->displayParameter()) {
        p[QStringLiteral("gridX")] = dp->gridRelativePositionX();
        p[QStringLiteral("gridY")] = dp->gridRelativePositionY();
        p[QStringLiteral("w")]     = dp->unitSizeWidth();
        p[QStringLiteral("h")]     = dp->unitSizeHeight();
    }
    return p;
}

GameplayEvent makeEvent(const QString &type, GameplayEventSource source,
                        QJsonObject payload, bool durable)
{
    GameplayEvent ev;
    ev.type    = type;
    ev.source  = source;
    ev.payload = std::move(payload);
    ev.durable = durable;
    // TODO(V3, D33) : `author` reste vide (= local/système) — les signaux
    // écoutés ici ne portent pas l'auteur d'une mutation distante. À
    // enrichir quand l'op bus / les deltas transporteront le playerId
    // jusqu'à ces signaux.
    return ev;
}

} // namespace

GameplayEventIngest::GameplayEventIngest(GameplayEventBus *bus, QObject *parent)
    : QObject(parent), m_bus(bus ? bus : GameplayEventBus::instance())
{
    // ── ItemSnapableEvents : vie des tuiles (source Editor) ────────────
    // created/deleted = durables (noyau d'audit D19) ; moved = éphémère
    // (cadence de drag). zoneParameterChanged = éphémère aussi : il feu à
    // la cadence des sliders (friction, vitesses…) — l'état final d'une
    // édition est de toute façon capté par la persistance de map.
    ItemSnapableEvents *ise = ItemSnapableEvents::instance();

    connect(ise, &ItemSnapableEvents::tileCreated, this,
            [this](ItemSnapable *tile) {
        m_bus->append(makeEvent(QStringLiteral("tile.created"),
                                GameplayEventSource::Editor,
                                tilePayload(tile), /*durable=*/true));
    });

    connect(ise, &ItemSnapableEvents::tileDeleted, this,
            [this](const QUuid &tileId, int tileType) {
        QJsonObject p;
        p[QStringLiteral("uuid")]     = tileId.toString(QUuid::WithoutBraces);
        p[QStringLiteral("tileType")] = tileType;
        m_bus->append(makeEvent(QStringLiteral("tile.deleted"),
                                GameplayEventSource::Editor,
                                p, /*durable=*/true));
    });

    connect(ise, &ItemSnapableEvents::tileMoved, this,
            [this](ItemSnapable *tile) {
        m_bus->append(makeEvent(QStringLiteral("tile.moved"),
                                GameplayEventSource::Editor,
                                tilePayload(tile), /*durable=*/false));
    });

    connect(ise, &ItemSnapableEvents::zoneParameterChanged, this,
            [this](ItemSnapable *tile) {
        m_bus->append(makeEvent(QStringLiteral("zone.parameterChanged"),
                                GameplayEventSource::Editor,
                                tilePayload(tile), /*durable=*/false));
    });

    // ── Game : cycle de vie map (source Game, durable) ─────────────────
    Game *game = Game::instance();

    connect(game, &Game::mapLoaded, this, [this](Map *map) {
        QJsonObject p;
        if (map) {
            p[QStringLiteral("tileCount")] = map->tiles().size();
            if (MapInfo *info = map->getMapInfo())
                p[QStringLiteral("mapName")] = info->getMapName();
        }
        m_bus->append(makeEvent(QStringLiteral("map.loaded"),
                                GameplayEventSource::Game,
                                p, /*durable=*/true));
    });

    // Distinct de tile.deleted (ItemSnapableEvents) : ici c'est le chemin
    // delta undo/redo de Game — même suppression, deux points de vue ;
    // le type et la source les distinguent (D33).
    connect(game, &Game::tileRemoved, this, [this](QUuid tileId) {
        QJsonObject p;
        p[QStringLiteral("uuid")] = tileId.toString(QUuid::WithoutBraces);
        m_bus->append(makeEvent(QStringLiteral("tile.removed"),
                                GameplayEventSource::Game,
                                p, /*durable=*/true));
    });

    // ── PhysicsSession : combat (source Physics, éphémère) ─────────────
    // PhysicsSession vit sur le GUI thread (ses slots sont nourris par les
    // signaux Catway livrés en queued sur le GUI thread) → connexion
    // directe sûre. On ne se branche PAS sur le worker physique lui-même.
    //
    // TODO(V3, piste D) : côté HÔTE, combatEventReceived n'est pas émis
    // (la résolution est locale, CombatController appelle
    // broadcastCombatEvent depuis QML) → seuls les clients journalisent
    // ces événements pour l'instant. À symétriser quand le canal combat
    // sera revisité (émettre aussi côté broadcast, ou brancher le
    // CombatController), sans toucher PhysicsSession depuis cet adaptateur.
    connect(PhysicsSession::instance(), &PhysicsSession::combatEventReceived,
            this, [this](const QVariantMap &payload) {
        m_bus->append(makeEvent(QStringLiteral("physics.combat"),
                                GameplayEventSource::Physics,
                                QJsonObject::fromVariantMap(payload),
                                /*durable=*/false));
    });
}
