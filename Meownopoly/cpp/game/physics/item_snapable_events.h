/*
 *      PattounX v2 — ItemSnapableEvents
 *
 * Agrégateur de signaux centralisant la "vie" des tuiles d'éditeur,
 * pour que les consommateurs (en premier lieu EditorPhysicsBridge) puissent
 * réagir à toutes les mutations sans s'abonner directement à chaque tuile.
 *
 *  - écoute MapFileManager::currentMapChanged pour suivre la Map active ;
 *  - rebranchement automatique sur Map::tileAddedToMap / tileRemovedFromMap ;
 *  - abonnements dynamiques aux signaux ZoneParameter / DisplayParameter
 *    de chaque tile pour émettre tileMoved / zoneParameterChanged.
 *
 *  Émet :
 *  - tileCreated(tile)         : nouvelle tile ajoutée ou map chargée
 *  - tileDeleted(id, tileType) : tile supprimée ou map démontée
 *  - tileMoved(tile)           : gridRelativePositionX/Y ou unitSize* changé
 *  - zoneParameterChanged(tile): polygon, friction, exclusion, vitesses, etc.
 *  - physicalObjectParameterChanged(tile): mass, bounce, friction, damping
 *
 * Singleton C++ exposé via QML `Pattounx.ItemSnapableEvents`.
 */
#ifndef ITEM_SNAPABLE_EVENTS_H
#define ITEM_SNAPABLE_EVENTS_H

#include <QHash>
#include <QObject>
#include <QPointer>
#include <QQmlEngine>
#include <QSet>
#include <QUuid>

class ItemSnapable;
class Map;

class ItemSnapableEvents : public QObject
{
    Q_OBJECT
public:
    static ItemSnapableEvents *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);
    static void registerQml();

    // Snapshot synchrone : permet à un consommateur instancié tardivement
    // (ex: PhysicsTestTab ouvert APRÈS la pose de zones dans l'éditeur) de
    // se rejouer l'état actuel sans attendre une nouvelle mutation.
    Q_INVOKABLE QVariantList currentTiles() const;

signals:
    void tileCreated(ItemSnapable *tile);
    void tileDeleted(const QUuid &tileId, int tileType);
    void tileMoved(ItemSnapable *tile);
    void zoneParameterChanged(ItemSnapable *tile);
    void physicalObjectParameterChanged(ItemSnapable *tile);

private slots:
    void onCurrentMapChanged();
    void onTileAddedToMap(ItemSnapable *tile);
    void onTileRemovedFromMap(const QUuid &tileId, int tileType);

private:
    explicit ItemSnapableEvents(QObject *parent = nullptr);
    static ItemSnapableEvents *m_instance;

    void attachMap(Map *map);
    void detachMap(Map *map, bool emitDeletedForAllTiles);
    void attachTile(ItemSnapable *tile);
    void detachTile(ItemSnapable *tile);

    QPointer<Map>          m_map;
    QSet<ItemSnapable *>   m_attachedTiles;
};

#endif // ITEM_SNAPABLE_EVENTS_H
