#include "pattounx_engine_v2.h"

#include <algorithm>
#include <cmath>

namespace pattounx {

PattounX_engine::PattounX_engine() = default;
PattounX_engine::~PattounX_engine() = default;

// --- Helpers ---

Polygon2D PattounX_engine::buildPolygon(const QVector<QVector2D> &points)
{
    Polygon2D poly;
    poly.points = points;
    poly.computeCache();
    return poly;
}

void PattounX_engine::wakeUp(InternalBody &body)
{
    if (body.isSleeping) {
        body.isSleeping = false;
        body.sleepFrameCount = 0;
    }
}

// --- Mutations bodies ---

void PattounX_engine::upsertBody(const BodySpec &spec)
{
    auto it = m_bodies.find(spec.id);
    if (it == m_bodies.end()) {
        InternalBody body;
        body.spec = spec;
        body.position = spec.position;
        body.previousPosition = spec.position;
        m_bodies.insert(spec.id, body);
    } else {
        // Préserver la cinématique en cours, ne mettre à jour que les params.
        it->spec = spec;
    }
}

void PattounX_engine::removeBody(const QString &id)
{
    m_bodies.remove(id);
    m_activeZonesPerBody.remove(id);
}

void PattounX_engine::clearBodies()
{
    m_bodies.clear();
    m_activeZonesPerBody.clear();
}

void PattounX_engine::setBodyPosition(const QString &id, QVector2D pos)
{
    auto it = m_bodies.find(id);
    if (it == m_bodies.end()) return;
    it->position = pos;
    it->previousPosition = pos; // téléportation : on annule le sweep CCD courant
    wakeUp(*it);
}

void PattounX_engine::setBodyInput(const QString &actorId, QVector2D input)
{
    auto it = m_bodies.find(actorId);
    if (it == m_bodies.end()) return;
    it->inputVector = input;
    if (input.lengthSquared() > 0.0001) wakeUp(*it);
}

void PattounX_engine::applyImpulse(const QString &id, QVector2D impulse)
{
    auto it = m_bodies.find(id);
    if (it == m_bodies.end()) return;
    if (it->spec.type == BodyType::Static) return;
    qreal inv = it->invMass();
    if (inv <= 0.0 && it->spec.type != BodyType::Kinematic) return;
    if (it->spec.type == BodyType::Kinematic) {
        // Kinematic : on autorise une impulsion comme un coup ponctuel sur la vélocité.
        it->velocity += impulse;
    } else {
        it->velocity += impulse * inv;
    }
    wakeUp(*it);
}

// --- Mutations zones ---

void PattounX_engine::upsertZone(const ZoneSpec &spec)
{
    if (spec.polygon.size() < 3) {
        // polygone temporairement invalide → ignorer plutôt que crash
        m_zones.remove(spec.id);
        return;
    }
    InternalZone z;
    z.spec = spec;
    z.polygon = buildPolygon(spec.polygon);
    m_zones.insert(spec.id, z);
}

void PattounX_engine::removeZone(const QString &id)
{
    m_zones.remove(id);
    // purger des activeZones
    for (auto it = m_activeZonesPerBody.begin(); it != m_activeZonesPerBody.end(); ++it) {
        it->remove(id);
    }
}

void PattounX_engine::clearZones()
{
    m_zones.clear();
    for (auto it = m_activeZonesPerBody.begin(); it != m_activeZonesPerBody.end(); ++it) {
        it->clear();
    }
}

// --- Step principal ---

void PattounX_engine::step(qreal dt)
{
    if (dt <= 0.0) return;

    m_residualContacts.clear();

    integrateBodies(dt);
    resolveBodyZoneCCD();
    resolveBodyBodyCCD();

    // Solver itératif sur les contacts résiduels (zone-body uniquement —
    // les body-body sont résolus par impulsion en CCD direct, suffisant
    // tant qu'on n'a pas d'empilement profond).
    for (int i = 0; i < VELOCITY_ITERATIONS; ++i) {
        runStaticPass();
    }
    correctPositions();
}

void PattounX_engine::integrateBodies(qreal dt)
{
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) {
        InternalBody &body = it.value();
        if (body.spec.type == BodyType::Static) continue;
        applyGroundFrictionAndZones(body);
        integrateBody(body, dt);
    }
}

void PattounX_engine::applyGroundFrictionAndZones(InternalBody &body)
{
    QSet<QString> currentZones;
    // Base = damping de la spec du body. Avant le fix, on initialisait à
    // DEFAULT_GROUND_DAMPING (constante 0.05), ce qui faisait que
    // body.spec.linearDamping était ignoré côté QML/JSON et que tous les
    // bodies se comportaient comme s'ils avaient damping=0.05 hors zones
    // (cf. PCP test : sliders linearDamping/static/dynamic friction sans
    // effet observable). Une zone à frictionStrength plus forte continue à
    // surclasser via le max ci-dessous.
    qreal currentDamping = body.spec.linearDamping;
    qreal currentAccelMul = 1.0;
    qreal currentSpeedMul = 1.0;

    QVector2D pos = body.position;

    for (auto it = m_zones.begin(); it != m_zones.end(); ++it) {
        const InternalZone &zone = it.value();
        if (zone.spec.exclusion) continue; // les zones d'exclusion ne diffusent pas d'effet
        if (!zone.polygon.boundingBox.contains(pos.x(), pos.y())) continue;
        if (!Collision2D::pointInPolygon(pos, zone.polygon)) continue;

        currentZones.insert(zone.spec.id);
        currentDamping = std::max(currentDamping, zone.spec.frictionStrength);

        if (zone.spec.velocityForce.lengthSquared() > 0.0) {
            body.forceAccumulator += zone.spec.velocityForce;
        }
        currentAccelMul *= zone.spec.accelerationMultiplier;
        currentSpeedMul *= zone.spec.speedMultiplier;
    }

    body.currentDamping = currentDamping;
    body.zoneAccelerationMultiplier = currentAccelMul;
    body.zoneSpeedMultiplier = currentSpeedMul;

    QSet<QString> &prev = m_activeZonesPerBody[body.spec.id];
    for (const QString &z : currentZones) {
        if (!prev.contains(z))
            m_pendingEvents.entered.append({ body.spec.id, z });
    }
    for (const QString &z : prev) {
        if (!currentZones.contains(z))
            m_pendingEvents.exited.append({ body.spec.id, z });
    }
    m_activeZonesPerBody[body.spec.id] = currentZones;
}

void PattounX_engine::integrateBody(InternalBody &body, qreal dt)
{
    if (body.spec.type == BodyType::Static) return;

    if (body.isSleeping) {
        bool hasInput = body.inputVector.lengthSquared() > 0.0001;
        bool hasForce = body.forceAccumulator.lengthSquared() > 0.0001;
        if (hasInput || hasForce) {
            body.isSleeping = false;
            body.sleepFrameCount = 0;
        } else {
            body.forceAccumulator = QVector2D();
            return;
        }
    }

    body.previousPosition = body.position;

    qreal effectiveMaxSpeed = body.spec.maxSpeed * body.zoneSpeedMultiplier;

    if (body.spec.type == BodyType::Kinematic) {
        if (body.inputVector.length() > 0.01) {
            QVector2D targetVelocity = body.inputVector * effectiveMaxSpeed;
            qreal blend = std::min<qreal>(
                1.0, body.spec.acceleration * body.zoneAccelerationMultiplier * dt);
            body.velocity += (targetVelocity - body.velocity) * blend;
        } else {
            qreal frictionFactor = std::pow(1.0 - body.currentDamping, dt * 60.0);
            body.velocity *= frictionFactor;
        }
    } else {
        // Dynamic : friction continue (pas de input)
        qreal frictionFactor = std::pow(1.0 - body.currentDamping, dt * 60.0);
        body.velocity *= frictionFactor;
    }

    // Forces externes
    qreal inv = body.invMass();
    if (inv > 0.0 || body.spec.type == BodyType::Kinematic) {
        QVector2D externalAccel;
        if (body.spec.type == BodyType::Kinematic) {
            externalAccel = body.forceAccumulator; // traité comme accel directe
        } else {
            externalAccel = body.forceAccumulator * inv;
        }
        body.velocity += externalAccel * dt;
    }

    // Cap soft sur vitesse max
    if (body.velocity.length() > effectiveMaxSpeed + 0.01) {
        qreal decel = std::pow(1.0 - body.currentDamping, dt * 60.0);
        body.velocity *= decel;
        if (body.velocity.length() < effectiveMaxSpeed) {
            body.velocity = body.velocity.normalized() * effectiveMaxSpeed;
        }
    }

    body.position += body.velocity * dt;

    // Sleep system
    if (body.velocity.lengthSquared() < SLEEP_VELOCITY_THRESHOLD * SLEEP_VELOCITY_THRESHOLD
        && body.inputVector.lengthSquared() < 0.0001) {
        body.sleepFrameCount++;
        if (body.sleepFrameCount >= SLEEP_FRAMES_REQUIRED) {
            body.velocity = QVector2D();
            body.isSleeping = true;
            body.sleepFrameCount = 0;
        }
    } else {
        body.sleepFrameCount = 0;
    }

    body.forceAccumulator = QVector2D();
}

void PattounX_engine::resolveBodyZoneCCD()
{
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) {
        InternalBody &body = it.value();
        if (body.spec.type == BodyType::Static) continue;
        if (body.isSleeping) continue;
        if (body.spec.shape.type != ShapeType::Circle) continue; // v2 ne gère que cercles

        QVector2D p0 = body.previousPosition;
        QVector2D p1 = body.position;
        QVector2D movement = p1 - p0;
        if (movement.lengthSquared() < EPSILON * EPSILON) continue;

        qreal earliestT = 1.0;
        bool hasContact = false;
        QString contactZoneId;
        QVector2D contactNormal;
        QVector2D contactClosest;

        qreal radius = body.spec.shape.radius;

        for (auto zit = m_zones.begin(); zit != m_zones.end(); ++zit) {
            const InternalZone &zone = zit.value();
            if (!zone.spec.exclusion) continue;

            QRectF extBox = zone.polygon.boundingBox.adjusted(-radius, -radius, radius, radius);
            QRectF moveBox(
                std::min(p0.x(), p1.x()) - radius,
                std::min(p0.y(), p1.y()) - radius,
                std::abs(p1.x() - p0.x()) + 2 * radius,
                std::abs(p1.y() - p0.y()) + 2 * radius);
            if (!moveBox.intersects(extBox)) continue;

            QVector<CollisionResult> results
                = Collision2D::checkCirclePolygonSweepAll(p0, p1, radius, zone.polygon);

            for (const CollisionResult &r : results) {
                if (r.t < earliestT) {
                    earliestT = r.t;
                    hasContact = true;
                    contactZoneId = zone.spec.id;
                    contactNormal = r.normal;
                    contactClosest = r.closestPoint;
                }
            }
        }

        if (hasContact && earliestT < 1.0) {
            QVector2D contactPos = p0 + earliestT * movement;
            body.position = contactPos + contactNormal * TUNNELING_BUFFER;

            qreal velAlongNormal = QVector2D::dotProduct(body.velocity, contactNormal);
            qreal impactSpeed = std::abs(velAlongNormal);

            if (velAlongNormal < 0) {
                body.velocity = Collision2D::applyBounce(
                    body.velocity, contactNormal,
                    body.spec.bounceFactor, body.spec.slideFactor);
            }

            body.isColliding = true;
            body.lastCollisionNormal = contactNormal;

            Collision c;
            c.bodyId = body.spec.id;
            c.other = contactZoneId;
            c.normal = contactNormal;
            c.impactSpeed = impactSpeed;
            m_pendingEvents.collisions.append(c);
        } else {
            body.isColliding = false;
        }
    }

    // Détection statique aux positions corrigées (résiduels au repos)
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) {
        InternalBody &body = it.value();
        if (body.spec.type == BodyType::Static) continue;
        if (body.isSleeping) continue;
        if (body.spec.shape.type != ShapeType::Circle) continue;

        for (auto zit = m_zones.begin(); zit != m_zones.end(); ++zit) {
            const InternalZone &zone = zit.value();
            if (!zone.spec.exclusion) continue;

            QVector<CollisionResult> results = Collision2D::checkCirclePolygonAll(
                body.position, body.spec.shape.radius, zone.polygon);
            for (const CollisionResult &r : results) {
                ResidualContact rc;
                rc.bodyId = body.spec.id;
                rc.zoneId = zone.spec.id;
                rc.normal = r.normal;
                rc.closestPoint = r.closestPoint;
                rc.penetration = r.penetration;
                m_residualContacts.append(rc);
            }
        }
    }
}

void PattounX_engine::resolveBodyBodyCCD()
{
    // O(n²) — adéquat tant qu'on a < ~20 bodies dynamiques. À optimiser
    // si nécessaire avec un grid hashing en Phase 6+ (multi-actors).
    QVector<QString> ids;
    ids.reserve(m_bodies.size());
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) ids.append(it.key());

    for (int i = 0; i < ids.size(); ++i) {
        for (int j = i + 1; j < ids.size(); ++j) {
            InternalBody &A = m_bodies[ids[i]];
            InternalBody &B = m_bodies[ids[j]];

            if (A.spec.shape.type != ShapeType::Circle) continue;
            if (B.spec.shape.type != ShapeType::Circle) continue;

            // Skip si les deux sont statiques ou les deux dorment
            if (A.spec.type == BodyType::Static && B.spec.type == BodyType::Static) continue;
            if (A.isSleeping && B.isSleeping) continue;

            QVector2D startA = A.previousPosition;
            QVector2D endA = A.position;
            QVector2D startB = B.previousPosition;
            QVector2D endB = B.position;

            QVector2D normal;
            qreal t = Collision2D::sweepCircleCircle(
                startA, endA, A.spec.shape.radius,
                startB, endB, B.spec.shape.radius,
                normal);

            if (t < 0.0) continue;

            // Rewind aux positions de contact
            QVector2D movA = endA - startA;
            QVector2D movB = endB - startB;
            QVector2D contactA = startA + t * movA;
            QVector2D contactB = startB + t * movB;

            qreal sumR = A.spec.shape.radius + B.spec.shape.radius;
            // Pousser légèrement hors contact
            QVector2D push = normal * TUNNELING_BUFFER * 0.5;

            // Réponse cinématique : ne déplacer que les bodies "mobiles"
            bool aMovable = (A.spec.type != BodyType::Static);
            bool bMovable = (B.spec.type != BodyType::Static);

            if (aMovable && bMovable) {
                A.position = contactA + push;
                B.position = contactB - push;
            } else if (aMovable) {
                A.position = contactA + push;
                B.position = contactB;
            } else if (bMovable) {
                A.position = contactA;
                B.position = contactB - push;
            }
            (void)sumR;

            // Impulsion : j = -(1+e) * vRel·n / (invA + invB)
            QVector2D vRel = A.velocity - B.velocity;
            qreal velAlongNormal = QVector2D::dotProduct(vRel, normal);
            if (velAlongNormal > 0) {
                // Bodies s'éloignent déjà — pas d'impulsion mais on a quand même
                // logué un contact (utile pour les FX).
                Collision c;
                c.bodyId = A.spec.id;
                c.other = B.spec.id;
                c.normal = normal;
                c.impactSpeed = 0.0;
                m_pendingEvents.collisions.append(c);
                continue;
            }

            // Masse inertielle pour le calcul d'impulsion : un Kinematic
            // contribue avec sa vraie masse (≠ `invMass()` qui retourne 0
            // pour Kinematic dans les passes statiques où on n'écrit pas
            // sa velocity). Sans ça, Kinematic = masse infinie et la masse
            // de l'autre body s'annule mathématiquement → toutes les
            // caisses, légères ou lourdes, reçoivent la même delta-vélocité.
            auto effInvMass = [](const InternalBody &b) -> qreal {
                if (b.spec.type == BodyType::Static) return 0.0;
                return b.spec.mass > 0.0 ? 1.0 / b.spec.mass : 0.0;
            };
            qreal invA = effInvMass(A);
            qreal invB = effInvMass(B);

            // Application : seul un Dynamic reçoit la modification de
            // velocity. Un Kinematic conserve la sienne (input-driven), un
            // Static ne bouge jamais.
            qreal applyA = (A.spec.type == BodyType::Dynamic) ? invA : 0.0;
            qreal applyB = (B.spec.type == BodyType::Dynamic) ? invB : 0.0;

            qreal totalInv = invA + invB;
            if (totalInv > 0.0) {
                qreal e = std::min(A.spec.restitution, B.spec.restitution);
                qreal jMag = -(1.0 + e) * velAlongNormal / totalInv;
                QVector2D impulse = normal * jMag;

                A.velocity += impulse * applyA;
                B.velocity -= impulse * applyB;

                // Friction Coulomb (moyenne géométrique)
                QVector2D vRelAfter = A.velocity - B.velocity;
                QVector2D tangent = vRelAfter
                    - QVector2D::dotProduct(vRelAfter, normal) * normal;
                qreal tLen = tangent.length();
                if (tLen > EPSILON) {
                    tangent /= tLen;
                    qreal jt = -QVector2D::dotProduct(vRelAfter, tangent) / totalInv;
                    qreal muS = std::sqrt(A.spec.staticFriction * B.spec.staticFriction);
                    QVector2D frictionImpulse;
                    if (std::abs(jt) < jMag * muS) {
                        frictionImpulse = jt * tangent;
                    } else {
                        qreal muD = std::sqrt(A.spec.dynamicFriction * B.spec.dynamicFriction);
                        frictionImpulse = -jMag * tangent * muD;
                    }
                    A.velocity += frictionImpulse * applyA;
                    B.velocity -= frictionImpulse * applyB;
                }
            }

            wakeUp(A);
            wakeUp(B);

            Collision c;
            c.bodyId = A.spec.id;
            c.other = B.spec.id;
            c.normal = normal;
            c.impactSpeed = std::abs(velAlongNormal);
            m_pendingEvents.collisions.append(c);
        }
    }
}

void PattounX_engine::runStaticPass()
{
    for (const ResidualContact &m : m_residualContacts) {
        auto it = m_bodies.find(m.bodyId);
        if (it == m_bodies.end()) continue;
        InternalBody &body = it.value();

        QVector2D rv = body.velocity;
        QVector2D normal = m.normal;
        qreal velAlongNormal = QVector2D::dotProduct(rv, normal);
        if (velAlongNormal > 0) continue;

        qreal e = body.spec.restitution;
        qreal inv = body.invMass();
        // Pour Kinematic invMass = 0 → on n'applique pas le solver newton.
        // On laisse le rewind CCD et la correction de position s'occuper
        // de la pénétration ; la vélocité reste pilotée par l'input.
        if (inv <= 0.0) continue;

        qreal jMag = -(1.0 + e) * velAlongNormal / inv;
        QVector2D impulse = jMag * normal;
        body.velocity += impulse * inv;

        rv = body.velocity;
        QVector2D tangent = rv - QVector2D::dotProduct(rv, normal) * normal;
        if (tangent.lengthSquared() <= EPSILON * EPSILON) continue;
        tangent.normalize();

        qreal jt = -QVector2D::dotProduct(rv, tangent) / inv;
        // Friction zone vs body
        qreal zoneFriction = 0.5;
        auto zit = m_zones.find(m.zoneId);
        if (zit != m_zones.end()) {
            qreal zf = zit->spec.frictionStrength;
            if (zf > 0.0) zoneFriction = zf;
        }
        qreal muS = std::sqrt(body.spec.staticFriction * zoneFriction);
        QVector2D frictionImpulse;
        if (std::abs(jt) < jMag * muS) {
            frictionImpulse = jt * tangent;
        } else {
            qreal muD = std::sqrt(body.spec.dynamicFriction * zoneFriction);
            frictionImpulse = -jMag * tangent * muD;
        }
        body.velocity += frictionImpulse * inv;
    }
}

void PattounX_engine::correctPositions()
{
    for (const ResidualContact &m : m_residualContacts) {
        auto it = m_bodies.find(m.bodyId);
        if (it == m_bodies.end()) continue;
        InternalBody &body = it.value();

        QVector2D toBody = body.position - m.closestPoint;
        qreal currentDist = toBody.length();

        // Centre à l'intérieur du polygone : le contact résiduel porte une
        // normale d'EXPULSION (cf. checkCirclePolygonAll) qui pointe du
        // centre vers l'extérieur, donc à l'opposé de `toBody`. Dans ce cas
        // la pénétration réelle est radius + dist (franchir l'arête puis
        // s'en écarter d'un rayon) et la poussée doit suivre la normale
        // stockée — recalculer depuis closestPoint enfoncerait le body.
        const bool inside = QVector2D::dotProduct(toBody, m.normal) < 0.0;
        qreal residual = inside ? (body.spec.shape.radius + currentDist)
                                : (body.spec.shape.radius - currentDist);
        if (residual <= PENETRATION_SLOP) continue;

        qreal mag = (residual - PENETRATION_SLOP) * POSITION_CORRECTION_PERCENT;
        QVector2D normal = inside ? m.normal
                                  : ((currentDist > EPSILON) ? toBody / currentDist : m.normal);
        body.position += normal * mag;
    }
}

// --- Snapshot & events ---

void PattounX_engine::writeSnapshot(WorldSnapshot &out, quint64 tick, qint64 timestampNs) const
{
    out.tick = tick;
    out.timestampNs = timestampNs;
    out.bodies.clear();
    out.bodies.reserve(m_bodies.size());
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) {
        const InternalBody &b = it.value();
        BodySnapshot snap;
        snap.id = b.spec.id;
        snap.position = b.position;
        snap.velocity = b.velocity;
        snap.isSleeping = b.isSleeping;
        snap.isColliding = b.isColliding;
        out.bodies.insert(snap.id, snap);
    }
}

PattounX_engine::Events PattounX_engine::takeEvents()
{
    Events out = std::move(m_pendingEvents);
    m_pendingEvents = Events();
    return out;
}

} // namespace pattounx
