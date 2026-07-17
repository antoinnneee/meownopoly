/*
 *      V3 Piste D — GameplayEventIngest (adaptateurs d'ingestion)
 *
 * Se branche à l'init du jeu sur les signaux métier existants et forge les
 * `GameplayEvent` correspondants vers le `GameplayEventBus` — sans déplacer
 * aucune logique métier :
 *
 *  - ItemSnapableEvents : tileCreated/tileDeleted (durables),
 *    tileMoved/zoneParameterChanged (éphémères, cadence de drag/slider) ;
 *  - Game : mapLoaded, tileRemoved (durables) ;
 *  - PhysicsSession : combatEventReceived (éphémère — signal émis sur le
 *    GUI thread, PhysicsSession vit sur le GUI thread).
 *
 * Contrairement au bus (linkable headless), cet adaptateur dépend du jeu
 * complet. Instancié dans qmlapp.cpp après les singletons concernés.
 */
#ifndef GAMEPLAY_EVENT_INGEST_H
#define GAMEPLAY_EVENT_INGEST_H

#include <QObject>

class GameplayEventBus;
class ItemSnapable;

class GameplayEventIngest : public QObject
{
    Q_OBJECT
public:
    explicit GameplayEventIngest(GameplayEventBus *bus,
                                 QObject *parent = nullptr);

private:
    GameplayEventBus *m_bus = nullptr;
};

#endif // GAMEPLAY_EVENT_INGEST_H
