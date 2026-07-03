/*
 *      PattounX v2 — moteur Qt-free
 *
 * Cœur de simulation extrait du QObject `PattounX_engine`. Ne possède
 * ni signaux ni slots — la communication se fait via `step` + `takeEvents`
 * + `writeSnapshot`. Conçu pour vivre dans un thread dédié piloté par
 * `PhysicsWorker` (Phase 2).
 */
#ifndef PATTOUNX_ENGINE_V2_H
#define PATTOUNX_ENGINE_V2_H

#include "collision2d.h"
#include "pattounx_types.h"

#include <QHash>
#include <QSet>
#include <QString>
#include <QVector>
#include <QVector2D>
#include <utility>

namespace pattounx {

class PattounX_engine
{
public:
    PattounX_engine();
    ~PattounX_engine();

    // --- Mutations ---
    void upsertBody(const BodySpec &spec);
    void removeBody(const QString &id);
    void clearBodies();

    void setBodyPosition(const QString &id, QVector2D pos);
    void setBodyInput(const QString &actorId, QVector2D input);
    void applyImpulse(const QString &id, QVector2D impulse);

    void upsertZone(const ZoneSpec &spec);
    void removeZone(const QString &id);
    void clearZones();

    // --- Simulation ---
    void step(qreal dt);

    // --- Accès lecture ---
    int bodyCount() const { return m_bodies.size(); }
    int zoneCount() const { return m_zones.size(); }
    bool hasBody(const QString &id) const { return m_bodies.contains(id); }
    bool hasZone(const QString &id) const { return m_zones.contains(id); }

    // Copie cinématique de tous les bodies vers le snapshot fourni.
    void writeSnapshot(WorldSnapshot &out, quint64 tick, qint64 timestampNs) const;

    // --- Événements ---
    struct Collision
    {
        QString bodyId;
        QString other;       // zoneId OU bodyId (body-body)
        QVector2D normal;    // pointe du `other` vers `bodyId`
        qreal impactSpeed = 0.0;
    };

    struct Events
    {
        QVector<std::pair<QString, QString>> entered;
        QVector<std::pair<QString, QString>> exited;
        QVector<Collision> collisions;
    };

    // Récupère et vide les événements accumulés depuis le dernier appel.
    Events takeEvents();

    // --- Constantes simu ---
    static constexpr qreal EPSILON = Collision2D::EPSILON;
    static constexpr int   VELOCITY_ITERATIONS = 4;
    static constexpr qreal PENETRATION_SLOP = 0.01;
    static constexpr qreal POSITION_CORRECTION_PERCENT = 0.6;
    static constexpr qreal TUNNELING_BUFFER = 0.02;
    static constexpr qreal DEFAULT_GROUND_DAMPING = 0.05;
    static constexpr qreal SLEEP_VELOCITY_THRESHOLD = 0.5;
    static constexpr int   SLEEP_FRAMES_REQUIRED = 30;

private:
    struct InternalBody
    {
        BodySpec spec;
        QVector2D position;
        QVector2D previousPosition;
        QVector2D velocity;
        QVector2D inputVector;
        QVector2D forceAccumulator;

        bool isColliding = false;
        QVector2D lastCollisionNormal;

        bool isSleeping = false;
        int sleepFrameCount = 0;

        qreal currentDamping = DEFAULT_GROUND_DAMPING;
        qreal zoneAccelerationMultiplier = 1.0;
        qreal zoneSpeedMultiplier = 1.0;

        qreal invMass() const
        {
            if (spec.type == BodyType::Static) return 0.0;
            if (spec.type == BodyType::Kinematic) return 0.0; // ignore body-body response
            return spec.mass > 0.0 ? 1.0 / spec.mass : 0.0;
        }
    };

    struct InternalZone
    {
        ZoneSpec spec;
        Polygon2D polygon;
    };

    // Pipeline interne
    void integrateBodies(qreal dt);
    void applyGroundFrictionAndZones(InternalBody &body);
    void integrateBody(InternalBody &body, qreal dt);
    void resolveBodyZoneCCD();
    void resolveBodyBodyCCD();
    // Collecte les contacts résiduels body-zone aux positions finales du
    // frame — appelée APRÈS resolveBodyBodyCCD pour voir aussi les bodies
    // poussés dans une zone par la résolution body-body. Un seul contact
    // par body (le plus pénétrant) : checkCirclePolygonAll produit un
    // contact par arête, et dans un coin deux impulsions avec restitution
    // chacune = sur-restitution + jitter.
    void collectResidualZoneContacts();
    void runStaticPass();
    void correctPositions();

    // Helpers
    static Polygon2D buildPolygon(const QVector<QVector2D> &points);
    void wakeUp(InternalBody &body);

    QHash<QString, InternalBody> m_bodies;
    QHash<QString, InternalZone> m_zones;
    QHash<QString, QSet<QString>> m_activeZonesPerBody;

    // Contacts résiduels accumulés au cours du step pour le solver.
    struct ResidualContact
    {
        QString bodyId;
        QString zoneId;
        QVector2D normal;
        QVector2D closestPoint;
        qreal penetration = 0.0;
    };
    QVector<ResidualContact> m_residualContacts;

    Events m_pendingEvents;
};

} // namespace pattounx

#endif // PATTOUNX_ENGINE_V2_H
