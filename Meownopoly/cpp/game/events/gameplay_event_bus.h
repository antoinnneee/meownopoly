/*
 *      V3 / M5 — GameplayEventBus (D1 : bus + ingestion)
 *
 * Journal d'événements métier unifié. Centralise, sous une forme typée et
 * horodatée logiquement, les signaux existants des briques V2 SANS déplacer
 * leur logique métier :
 *   - Game               (cycle de vie carte/partie ; game.h:105-121)
 *   - EditorOpBus        (mutations d'éditeur locales/distantes)
 *   - ItemSnapableEvents (vie des tuiles ; item_snapable_events.h:47-51)
 *   - PhysicsSession     (combat / runtime physique)
 *
 * Périmètre D1 : le bus et l'INGESTION seulement. Le curseur/snapshot d'audit
 * robuste (D2), les protections de cascade/cycles (D3) et le branchement au
 * canal IA `events_poll` (D4) sont des tâches distinctes — un journal borné en
 * mémoire est fourni ici comme socle minimal.
 *
 * Threads : le bus vit sur le thread GUI. L'ingestion physique passe par
 * PhysicsSession (elle-même sur le thread GUI), mais la simulation Pattounx
 * tourne dans un worker dédié — publish() est donc thread-safe (ré-ordonnancé
 * en QueuedConnection s'il est appelé hors du thread du bus) et les connexions
 * physiques sont posées en Qt::QueuedConnection par prudence.
 */
#ifndef GAMEPLAY_EVENT_BUS_H
#define GAMEPLAY_EVENT_BUS_H

#include <QObject>
#include <QQmlEngine>
#include <QVariantList>
#include <QVariantMap>
#include <QVector>

#include "event_types.h"

class GameplayEventBus : public QObject
{
    Q_OBJECT

    // Nombre total d'événements ingérés depuis le démarrage (monotone).
    Q_PROPERTY(quint64 eventCount READ eventCount NOTIFY eventCountChanged)
    // Dernière valeur d'horloge de Lamport attribuée.
    Q_PROPERTY(qint64 logicalClock READ logicalClock NOTIFY eventCountChanged)

public:
    static void registerQml();
    static GameplayEventBus *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    quint64 eventCount() const   { return m_eventCount; }
    qint64  logicalClock() const { return m_logicalClock; }

    // Publication programmatique d'un événement. Utilisée par l'ingestion des
    // sources et, à terme, par les artefacts/règles. Retourne l'id généré.
    // Thread-safe : si appelée depuis un autre thread que celui du bus,
    // l'ingestion est ré-ordonnancée en QueuedConnection. `type`/`source`
    // sont des valeurs de meow::EventType / meow::EventSource.
    Q_INVOKABLE QString publish(int type, int source, const QString &author,
                                const QVariantMap &payload = {},
                                const QString &causeId = {});

    // Connecte les sources d'ingestion. Idempotent : appelable plusieurs fois
    // (les instances de singleton manquantes sont créées à la volée). Invoqué
    // au boot par le bootstrap une fois l'event loop démarrée.
    Q_INVOKABLE void connectSources();

    // Ré-injecte le ts distant dans l'horloge locale (Lamport : le prochain
    // tick local sera > à tout ts vu). Utilisé quand un événement porteur d'un
    // ts logique arrive du réseau (consommé par D2/collab).
    Q_INVOKABLE void syncLogicalClock(qint64 remoteTs);

    // Journal courant (borné) projeté en QVariantMap, du plus ancien au plus
    // récent. Socle pour tests/debug ; D2 fournira curseur + snapshot robustes.
    Q_INVOKABLE QVariantList recentEvents(int max = 100) const;

signals:
    // Émis pour chaque événement ingéré (durable ou éphémère). Les abonnés
    // filtrent par `source`/`type`/`durability` dans la charge projetée.
    void eventPublished(const QVariantMap &event);
    void eventCountChanged();

private:
    explicit GameplayEventBus(QObject *parent = nullptr);
    static GameplayEventBus *m_instance;

    // Horloge de Lamport locale — même principe que game_lamport.cpp : un
    // compteur logique monotone. On garde une horloge DÉDIÉE aux événements
    // plutôt que de réutiliser Game::tickLamport() (qui pilote le zOrder des
    // tuiles et serait pollué par la cadence des événements — cf. note de
    // conception dans le .cpp).
    qint64 tickLamport();

    // Marshalling thread-safe puis archivage + diffusion.
    void dispatchIngest(const meow::GameplayEvent &ev);
    void ingest(meow::GameplayEvent ev);

    // Câblage par source (chacune tolère l'absence de son singleton).
    void connectGame();
    void connectEditorOps();
    void connectTiles();
    void connectPhysics();

    bool    m_sourcesConnected = false;
    qint64  m_logicalClock     = 0;
    quint64 m_eventCount       = 0;

    // Journal en mémoire, borné (ring souple). Remplacé par curseur+snapshot
    // durables en D2.
    QVector<meow::GameplayEvent> m_journal;
    static constexpr int k_journalCap = 4096;
};

#endif // GAMEPLAY_EVENT_BUS_H
