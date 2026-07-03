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

const QVector<const PattounX_engine::InternalZone *> &PattounX_engine::effectZones()
{
    if (m_effectZonesDirty) {
        m_effectZonesCache.clear();
        for (auto it = m_zones.constBegin(); it != m_zones.constEnd(); ++it) {
            if (!it->spec.exclusion) m_effectZonesCache.append(&it.value());
        }
        m_effectZonesDirty = false;
    }
    return m_effectZonesCache;
}

void PattounX_engine::wakeBodiesTouchingZone(const InternalZone &zone)
{
    // Test grossier AABB gonflée du rayon — un faux positif ne coûte qu'un
    // réveil (le body se rendort en ~30 frames s'il n'est pas concerné).
    const QRectF box = zone.polygon.boundingBox;
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) {
        InternalBody &b = it.value();
        if (!b.isSleeping) continue;
        const qreal r = (b.spec.shape.type == ShapeType::Circle) ? b.spec.shape.radius : 0.0;
        if (box.adjusted(-r, -r, r, r).contains(b.position.x(), b.position.y()))
            wakeUp(b);
    }
}

// --- Mutations bodies ---

void PattounX_engine::upsertBody(const BodySpec &spec)
{
    if (spec.shape.type != ShapeType::Circle) {
        // ShapeType::Polygon est déclaré dans l'API mais non implémenté par
        // les résolutions (toutes skippent les non-cercles) : un body
        // polygone ne collisionnerait avec RIEN, silencieusement. Rejet
        // explicite plutôt qu'un body fantôme.
        qWarning("PattounX: upsertBody('%s') rejeté — seul ShapeType::Circle est supporté",
                 qPrintable(spec.id));
        return;
    }

    auto it = m_bodies.find(spec.id);
    if (it == m_bodies.end()) {
        InternalBody body;
        body.spec = spec;
        body.position = spec.position;
        body.previousPosition = spec.position;
        m_bodies.insert(spec.id, body);
    } else {
        // Préserver la cinématique en cours, ne mettre à jour que les params
        // (spec.position ignorée — cf. doc du .h, setBodyPosition pour
        // téléporter). Un changement de shape réveille le body : un radius
        // agrandi peut créer une pénétration sous un body endormi.
        const bool shapeChanged = it->spec.shape.type != spec.shape.type
                                  || it->spec.shape.radius != spec.shape.radius;
        it->spec = spec;
        if (shapeChanged) wakeUp(*it);
    }
}

void PattounX_engine::removeBody(const QString &id)
{
    // Émettre les `exited` des zones encore actives avant de retirer le
    // body : les consommateurs à pile de zones (QML) garderaient sinon un
    // état orphelin pour toujours.
    auto zit = m_activeZonesPerBody.constFind(id);
    if (zit != m_activeZonesPerBody.constEnd()) {
        for (const QString &z : zit.value())
            m_pendingEvents.exited.append({ id, z });
    }
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
    auto old = m_zones.find(spec.id);
    if (spec.polygon.size() < 3) {
        // polygone temporairement invalide → ignorer plutôt que crash
        if (old != m_zones.end()) {
            wakeBodiesTouchingZone(old.value());
            m_zones.erase(old);
        }
        return;
    }
    InternalZone z;
    z.spec = spec;
    z.polygon = buildPolygon(spec.polygon);
    // Réveiller les bodies endormis touchés par l'ANCIENNE et la NOUVELLE
    // empreinte : une zone draguée sur une caisse endormie resterait sinon
    // enfouie (les résolutions skippent les bodies endormis) ; symétriquement
    // une zone qui s'éloigne doit laisser la détection re-statuer.
    if (old != m_zones.end()) wakeBodiesTouchingZone(old.value());
    wakeBodiesTouchingZone(z);
    m_zones.insert(spec.id, z);
    m_effectZonesDirty = true;
}

void PattounX_engine::removeZone(const QString &id)
{
    auto it = m_zones.find(id);
    if (it != m_zones.end()) {
        wakeBodiesTouchingZone(it.value());
        m_zones.erase(it);
        m_effectZonesDirty = true;
    }
    // purger des activeZones
    for (auto it = m_activeZonesPerBody.begin(); it != m_activeZonesPerBody.end(); ++it) {
        it->remove(id);
    }
}

void PattounX_engine::clearZones()
{
    m_zones.clear();
    m_effectZonesDirty = true;
    for (auto it = m_activeZonesPerBody.begin(); it != m_activeZonesPerBody.end(); ++it) {
        it->clear();
    }
}

// --- Step principal ---

void PattounX_engine::step(qreal dt)
{
    if (dt <= 0.0) return;

    m_residualContacts.clear();

    // isColliding : reset en début de step pour les bodies éveillés, puis
    // levé par CHAQUE résolution (body-zone CCD, body-body, résiduels) —
    // avant, seul le body-zone le pilotait et uniquement dans certaines
    // branches. Un body endormi garde son dernier état (cinématique gelée).
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) {
        if (!it->isSleeping) it->isColliding = false;
    }

    integrateBodies(dt);
    resolveBodyZoneCCD(dt);
    resolveBodyBodyCCD();
    // Collecte APRÈS le body-body : un body poussé dans une zone d'exclusion
    // par la résolution body-body doit avoir son contact résiduel CE frame,
    // sinon la pénétration persiste au moins une frame (définitivement dans
    // le pire cas coin/inside).
    collectResidualZoneContacts();

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

    // Cache des zones à effet : la plupart des maps n'ont que des murs
    // (exclusion) — inutile d'itérer m_zones entier par body à 60 Hz.
    const QVector<const InternalZone *> &zones = effectZones();
    QSet<QString> &prev = m_activeZonesPerBody[body.spec.id];

    if (zones.isEmpty() && prev.isEmpty()) {
        // Cas courant : rien à diffuser ni à diff-er. Le clamp reste
        // nécessaire (spec.linearDamping non borné en amont, cf. M3).
        body.currentDamping = std::clamp(currentDamping, 0.0, 0.999);
        body.zoneAccelerationMultiplier = 1.0;
        body.zoneSpeedMultiplier = 1.0;
        return;
    }

    // Scratch réutilisé (pas d'allocation par body/frame ; l'affectation
    // finale à `prev` est un shallow copy COW).
    QSet<QString> &currentZones = m_scratchZones;
    currentZones.clear();

    QVector2D pos = body.position;

    for (const InternalZone *zone : zones) {
        if (!zone->polygon.boundingBox.contains(pos.x(), pos.y())) continue;
        if (!Collision2D::pointInPolygon(pos, zone->polygon)) continue;

        currentZones.insert(zone->spec.id);
        currentDamping = std::max(currentDamping, zone->spec.frictionStrength);

        if (zone->spec.velocityForce.lengthSquared() > 0.0) {
            body.forceAccumulator += zone->spec.velocityForce;
        }
        currentAccelMul *= zone->spec.accelerationMultiplier;
        currentSpeedMul *= zone->spec.speedMultiplier;
    }

    // Clamp de sécurité : damping >= 1 (valeur pilotée par l'éditeur, non
    // bornée en amont) rendrait `std::pow(1.0 - damping, dt*60)` négatif ou
    // NaN — qui contamine velocity puis position définitivement, et se
    // propage à tous les clients via snapshot.
    body.currentDamping = std::clamp(currentDamping, 0.0, 0.999);
    body.zoneAccelerationMultiplier = currentAccelMul;
    body.zoneSpeedMultiplier = currentSpeedMul;

    for (const QString &z : currentZones) {
        if (!prev.contains(z))
            m_pendingEvents.entered.append({ body.spec.id, z });
    }
    for (const QString &z : prev) {
        if (!currentZones.contains(z))
            m_pendingEvents.exited.append({ body.spec.id, z });
    }
    prev = currentZones;
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

    // Cap soft sur vitesse max — décélération minimale garantie : à damping
    // nul, decel vaudrait 1.0 et un body recevant une grosse impulsion
    // (applyImpulse, velocityForce de zone) dépasserait maxSpeed indéfiniment.
    if (body.velocity.length() > effectiveMaxSpeed + 0.01) {
        qreal capDamping = std::max(body.currentDamping, DEFAULT_GROUND_DAMPING);
        qreal decel = std::pow(1.0 - capDamping, dt * 60.0);
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

void PattounX_engine::resolveBodyZoneCCD(qreal dt)
{
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) {
        InternalBody &body = it.value();
        if (body.spec.type == BodyType::Static) continue;
        if (body.isSleeping) continue;
        if (body.spec.shape.type != ShapeType::Circle) continue; // v2 ne gère que cercles

        const qreal radius = body.spec.shape.radius;

        // Après un impact, le mouvement restant du frame est ré-intégré avec
        // la vélocité post-rebond puis re-sweepé — avant, la fraction
        // (1-t)*dt était jetée : murs "collants", slide oblique ralenti.
        // Itérations bornées (MAX_SLIDE_ITERATIONS) : le résiduel éventuel
        // est repris par collectResidualZoneContacts + correctPositions.
        QVector2D sweepStart = body.previousPosition;
        qreal remainingDt = dt;

        for (int pass = 0; pass <= MAX_SLIDE_ITERATIONS; ++pass) {
            const QVector2D p0 = sweepStart;
            const QVector2D p1 = body.position;
            const QVector2D movement = p1 - p0;
            if (movement.lengthSquared() < EPSILON * EPSILON) break;

            qreal earliestT = 1.0;
            bool hasContact = false;
            QString contactZoneId;
            QVector2D contactNormal;

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
                    }
                }
            }

            if (!hasContact || earliestT >= 1.0) break;

            const QVector2D contactPos = p0 + earliestT * movement;
            body.position = contactPos + contactNormal * TUNNELING_BUFFER;

            const qreal velAlongNormal = QVector2D::dotProduct(body.velocity, contactNormal);
            const qreal impactSpeed = std::abs(velAlongNormal);

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

            // Ré-intégration du temps restant avec la vélocité post-impact.
            // Sur la dernière passe autorisée on s'arrête au point de contact
            // (pas de mouvement non re-sweepé laissé en l'état).
            remainingDt *= (1.0 - earliestT);
            if (pass == MAX_SLIDE_ITERATIONS || remainingDt <= 0.0) break;
            if (body.velocity.lengthSquared() < EPSILON * EPSILON) break;

            sweepStart = body.position;
            body.position += body.velocity * remainingDt;
        }
    }

}

void PattounX_engine::collectResidualZoneContacts()
{
    // Détection statique aux positions finales du frame (post body-zone CCD
    // ET post body-body — cf. commentaire dans step()). Dédup par body : on
    // ne garde que le contact le plus pénétrant, sinon un coin (2 arêtes)
    // applique deux impulsions avec restitution + jusqu'à 1.2× de
    // sur-correction positionnelle → jitter. Le mur "perdant" est repris au
    // frame suivant par la correction Baumgarte (convergence en 2-3 frames).
    QHash<QString, int> contactIndexByBody;
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

                const auto cit = contactIndexByBody.constFind(body.spec.id);
                if (cit == contactIndexByBody.constEnd()) {
                    contactIndexByBody.insert(body.spec.id, m_residualContacts.size());
                    m_residualContacts.append(rc);
                    body.isColliding = true;
                    body.lastCollisionNormal = rc.normal;
                } else if (rc.penetration > m_residualContacts[cit.value()].penetration) {
                    m_residualContacts[cit.value()] = rc;
                    body.lastCollisionNormal = rc.normal;
                }
            }
        }
    }
}

void PattounX_engine::resolveBodyBodyCCD()
{
    // O(n²) — adéquat tant qu'on a < ~20 bodies dynamiques. À optimiser
    // si nécessaire avec un grid hashing en Phase 6+ (multi-actors).
    //
    // Collecte de POINTEURS (stables dans QHash tant qu'on ne mute pas la
    // table — aucune mutation ici) : évite la reconstruction d'un
    // QVector<QString> + 2 lookups hash QString par paire à 60 Hz. Les
    // non-cercles sont filtrés d'emblée (aucune résolution ne les gère).
    // Tri par id : l'ordre d'itération d'un QHash dépend du seed de hash,
    // donc l'ordre de résolution des paires (et le résultat de la frame)
    // divergeait entre deux instances à inputs égaux — sans conséquence en
    // host-authoritative, mais gratuit à stabiliser à cette échelle.
    QVector<InternalBody *> bodies;
    bodies.reserve(m_bodies.size());
    for (auto it = m_bodies.begin(); it != m_bodies.end(); ++it) {
        if (it->spec.shape.type != ShapeType::Circle) continue;
        bodies.append(&it.value());
    }
    std::sort(bodies.begin(), bodies.end(),
              [](const InternalBody *a, const InternalBody *b) {
                  return a->spec.id < b->spec.id;
              });

    for (int i = 0; i < bodies.size(); ++i) {
        for (int j = i + 1; j < bodies.size(); ++j) {
            InternalBody &A = *bodies[i];
            InternalBody &B = *bodies[j];

            // Skip si les deux sont statiques ou les deux dorment
            if (A.spec.type == BodyType::Static && B.spec.type == BodyType::Static) continue;
            if (A.isSleeping && B.isSleeping) continue;

            QVector2D startA = A.previousPosition;
            QVector2D endA = A.position;
            QVector2D startB = B.previousPosition;
            QVector2D endB = B.position;

            // Early-out AABB des capsules de mouvement avant le sweep
            // quadratique (la grande majorité des paires est loin l'une de
            // l'autre). Marge EPSILON pour ne pas rater un contact exact
            // au bord.
            const qreal rA = A.spec.shape.radius;
            const qreal rB = B.spec.shape.radius;
            const QRectF boxA(std::min(startA.x(), endA.x()) - rA - EPSILON,
                              std::min(startA.y(), endA.y()) - rA - EPSILON,
                              std::abs(endA.x() - startA.x()) + 2 * (rA + EPSILON),
                              std::abs(endA.y() - startA.y()) + 2 * (rA + EPSILON));
            const QRectF boxB(std::min(startB.x(), endB.x()) - rB,
                              std::min(startB.y(), endB.y()) - rB,
                              std::abs(endB.x() - startB.x()) + 2 * rB,
                              std::abs(endB.y() - startB.y()) + 2 * rB);
            if (!boxA.intersects(boxB)) continue;

            QVector2D normal;
            qreal t = Collision2D::sweepCircleCircle(
                startA, endA, A.spec.shape.radius,
                startB, endB, B.spec.shape.radius,
                normal);

            if (t < 0.0) continue;

            qreal sumR = A.spec.shape.radius + B.spec.shape.radius;

            // Réponse cinématique : ne déplacer que les bodies "mobiles"
            bool aMovable = (A.spec.type != BodyType::Static);
            bool bMovable = (B.spec.type != BodyType::Static);

            // Masse inertielle pour l'impulsion et la répartition de la
            // correction : un Kinematic contribue avec sa vraie masse
            // (≠ `invMass()` qui retourne 0 pour Kinematic dans les passes
            // statiques où on n'écrit pas sa velocity). Sans ça, Kinematic
            // = masse infinie et la masse de l'autre body s'annule
            // mathématiquement → toutes les caisses, légères ou lourdes,
            // reçoivent la même delta-vélocité.
            auto effInvMass = [](const InternalBody &b) -> qreal {
                if (b.spec.type == BodyType::Static) return 0.0;
                return b.spec.mass > 0.0 ? 1.0 / b.spec.mass : 0.0;
            };
            qreal invA = effInvMass(A);
            qreal invB = effInvMass(B);

            if (t <= 0.0) {
                // Déjà en interpénétration au début du frame : le rewind à
                // t=0 annulerait le mouvement du frame sans séparer, et le
                // push fixe TUNNELING_BUFFER/2 (0.01/frame, indépendant de
                // la profondeur) mettrait ~30 frames à séparer deux cercles
                // enfoncés de 0.3, avec normale instable → jitter.
                // Correction proportionnelle à la profondeur (mêmes
                // constantes que correctPositions), répartie selon invMass.
                QVector2D delta = A.position - B.position;
                qreal dist = delta.length();
                if (dist > EPSILON) normal = delta / dist; // normale aux positions courantes
                qreal penetration = sumR - dist;
                if (penetration > PENETRATION_SLOP) {
                    qreal corr = (penetration - PENETRATION_SLOP)
                                 * POSITION_CORRECTION_PERCENT;
                    qreal wA = aMovable ? invA : 0.0;
                    qreal wB = bMovable ? invB : 0.0;
                    qreal wSum = wA + wB;
                    if (wSum <= 0.0) {
                        // Mobiles sans masse exploitable (Kinematic mass<=0) :
                        // répartition égale entre les bodies déplaçables.
                        wA = aMovable ? 1.0 : 0.0;
                        wB = bMovable ? 1.0 : 0.0;
                        wSum = wA + wB;
                    }
                    if (wSum > 0.0) {
                        A.position += normal * (corr * wA / wSum);
                        B.position -= normal * (corr * wB / wSum);
                    }
                }
            } else {
                // Rewind aux positions de contact + léger push hors contact
                QVector2D contactA = startA + t * (endA - startA);
                QVector2D contactB = startB + t * (endB - startB);
                QVector2D push = normal * TUNNELING_BUFFER * 0.5;
                if (aMovable) A.position = contactA + (bMovable ? push : 2.0 * push);
                if (bMovable) B.position = contactB - (aMovable ? push : 2.0 * push);
            }

            // Impulsion : j = -(1+e) * vRel·n / (invA + invB)
            // Contact avéré (t valide) : refléter dans l'état des deux bodies,
            // quel que soit le chemin de résolution pris ensuite.
            A.isColliding = true;
            B.isColliding = true;
            A.lastCollisionNormal = normal;
            B.lastCollisionNormal = -normal;

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
                    // <= : régime statique jusqu'à la limite de Coulomb incluse.
                    if (std::abs(jt) <= jMag * muS) {
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
        // Friction zone vs body — la valeur de la zone est prise telle
        // quelle (clampée ≥ 0) : frictionStrength == 0 est légitime (zone
        // glissante). Le défaut 0.5 ne couvre que le cas "zone disparue
        // entre la collecte et le solve".
        qreal zoneFriction = 0.5;
        auto zit = m_zones.find(m.zoneId);
        if (zit != m_zones.end()) {
            zoneFriction = std::max<qreal>(0.0, zit->spec.frictionStrength);
        }
        qreal muS = std::sqrt(body.spec.staticFriction * zoneFriction);
        QVector2D frictionImpulse;
        // <= : le régime statique tient jusqu'à la limite de Coulomb incluse.
        if (std::abs(jt) <= jMag * muS) {
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
