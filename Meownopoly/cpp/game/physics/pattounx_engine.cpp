#include "pattounx_engine.h"
#include "game/item_snapable/ItemSnapable.h"
#include "game/item_snapable/ZoneParameter.h"
#include <QDebug>
#include <QSet>
#include <QPair>
#include <QtQml>

void PattounX_engine::registerQml()
{
    qmlRegisterType<PattounX_engine>("PattounX", 1, 0, "PattounX_engine");
    qmlRegisterType<PattounX_body>("PattounX", 1, 0, "PattounX_body");
    qmlRegisterType<PattounX_zone>("PattounX", 1, 0, "PattounX_zone");

}

PattounX_engine::PattounX_engine(QObject* parent)
    : QObject(parent)
{
}

PattounX_engine::~PattounX_engine()
{
    clearBodies();
    clearZones();
}

// --- Setters ---

void PattounX_engine::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit enabledChanged();
    }
}

void PattounX_engine::setDebugMode(bool debug)
{
    if (m_debugMode != debug) {
        m_debugMode = debug;
        emit debugModeChanged();
    }
}

// --- Gestion des Bodies ---

PattounX_body* PattounX_engine::createBody(const QString& id)
{
    if (m_bodies.contains(id)) {
        qWarning() << "[PattounX_engine] Body with id" << id << "already exists";
        return m_bodies[id];
    }
    
    PattounX_body* body = new PattounX_body(id, this);
    body->setEngine(this);
    m_bodies[id] = body;
    
    if (m_debugMode) {
        qDebug() << "[PattounX_engine] Created body:" << id;
    }
    
    emit bodyCountChanged();
    return body;
}

bool PattounX_engine::removeBody(const QString& id)
{
    if (!m_bodies.contains(id)) {
        return false;
    }
    
    PattounX_body* body = m_bodies.take(id);
    m_activeZonesPerBody.remove(body);
    body->deleteLater();
    
    if (m_debugMode) {
        qDebug() << "[PattounX_engine] Removed body:" << id;
    }
    
    emit bodyCountChanged();
    return true;
}

PattounX_body* PattounX_engine::getBody(const QString& id) const
{
    return m_bodies.value(id, nullptr);
}

void PattounX_engine::clearBodies()
{
    for (PattounX_body* body : m_bodies) {
        body->deleteLater();
    }
    m_bodies.clear();
    m_activeZonesPerBody.clear();
    emit bodyCountChanged();
}

// --- Gestion des Zones ---

PattounX_zone* PattounX_engine::createZone(ItemSnapable* snapable)
{
    if (!snapable) return nullptr;
    QString id = snapable->uniqueId().toString();

    if (m_zones.contains(id)) {
        qWarning() << "[PattounX_engine] Zone with id" << id << "already exists";
        return m_zones[id];
    }

    PattounX_zone* zone = new PattounX_zone(snapable, this);
    m_zones[id] = zone;

    if (m_debugMode) {
        qDebug() << "[PattounX_engine] Created zone:" << id;
    }

    emit zoneCountChanged();
    return zone;
}

bool PattounX_engine::removeZone(const QString& id)
{
    if (!m_zones.contains(id)) {
        return false;
    }
    
    PattounX_zone* zone = m_zones.take(id);
    
    // Nettoyer les références dans activeZonesPerBody
    for (auto& activeZones : m_activeZonesPerBody) {
        activeZones.remove(zone);
    }
    
    zone->deleteLater();
    
    if (m_debugMode) {
        qDebug() << "[PattounX_engine] Removed zone:" << id;
    }
    
    emit zoneCountChanged();
    return true;
}

PattounX_zone* PattounX_engine::getZone(const QString& id) const
{
    return m_zones.value(id, nullptr);
}

void PattounX_engine::clearZones()
{
    for (PattounX_zone* zone : m_zones) {
        zone->deleteLater();
    }
    m_zones.clear();
    
    // Vider les zones actives
    for (auto& activeZones : m_activeZonesPerBody) {
        activeZones.clear();
    }
    
    emit zoneCountChanged();
}

void PattounX_engine::setZonesFromSnapables(const QVariantList& snapables)
{
    clearZones();

    for (const QVariant& var : snapables) {
        QObject* obj = var.value<QObject*>();
        ItemSnapable* snapable = qobject_cast<ItemSnapable*>(obj);
        
        if (!snapable) continue;
        
        ItemSnapable::TileType tileType = snapable->tileType();
        ZoneParameter* zoneParam = snapable->zoneParameter();
        
        if (!zoneParam || zoneParam->pointCount() < 3) continue;
        
        // Déterminer le type de zone
        
        if (tileType == ItemSnapable::PhysicZoneTile) {
            // physics zone (exclusion)
        } else {
            continue; // Ignore other types for now
        }
        
        // Créer la zone
        PattounX_zone* zone = createZone(snapable);

        if (m_debugMode && zone) {
            qDebug() << "[PattounX_engine] Loaded zone from snapable:"
                     << "points:" << zoneParam->pointCount();
        }
    }
    
    if (m_debugMode) {
        qDebug() << "[PattounX_engine] Loaded" << m_zones.size() << "zones from snapables";
    }
}

// --- Simulation ---

void PattounX_engine::updateAll(qreal dt)
{
    if (!m_enabled || dt <= 0) return;

    // 1. Intégrer tous les bodies (friction, zones, accélération, vitesse, position)
    for (PattounX_body* body : m_bodies) {
        updateBody(body, dt);
    }

    // 2. CCD sweep + rewind (anti-tunneling)
    //    Pour chaque body, on cherche la collision la plus proche (t minimal)
    //    puis on ramène le body au point d'impact et on applique le bounce.
    QSet<QPair<PattounX_body*, PattounX_zone*>> collidedPairs;

    for (PattounX_body* body : m_bodies) {
        if (!body->collisionEnabled() || body->isStatic() || body->isSleeping()) continue;

        QVector2D p0 = body->previousPosition();
        QVector2D p1 = body->position();
        QVector2D movement = p1 - p0;

        // Skip si pas de mouvement significatif
        if (movement.lengthSquared() < Collision2D::EPSILON * Collision2D::EPSILON) continue;

        qreal earliestT = 1.0;
        CollisionResult earliestContact;
        bool hasContact = false;

        for (PattounX_zone* zone : m_zones) {
            if (!zone->isActive() || !zone->exclusion()) continue;

            // Broadphase AABB : skip si le mouvement n'intersecte pas la zone élargie
            {
                qreal r = body->collisionRadius();
                QRectF extBox = zone->boundingBox().adjusted(-r, -r, r, r);
                QRectF moveBox(
                    std::min(p0.x(), p1.x()) - r,
                    std::min(p0.y(), p1.y()) - r,
                    std::abs(p1.x() - p0.x()) + 2 * r,
                    std::abs(p1.y() - p0.y()) + 2 * r
                );
                if (!moveBox.intersects(extBox)) continue;
            }

            QVector<CollisionResult> results = zone->checkCollisionSweepAll(p0, p1, body->collisionRadius());

            for (const CollisionResult& result : results) {
                collidedPairs.insert(qMakePair(body, result.zone));

                if (result.t < earliestT) {
                    earliestT = result.t;
                    earliestContact = result;
                    earliestContact.body = body;
                    hasContact = true;
                }
            }
        }

        // Rewind au point d'impact + bounce/slide sur la vélocité
        if (hasContact && earliestT < 1.0) {
            QVector2D contactPos = p0 + earliestT * movement;
            // Pousser légèrement hors de la surface de collision
            body->movePosition(contactPos + earliestContact.normal * TUNNELING_BUFFER);

            // Appliquer le bounce/slide sur la vélocité
            QVector2D vel = body->velocity();
            qreal velAlongNormal = QVector2D::dotProduct(vel, earliestContact.normal);
            if (velAlongNormal < 0) {
                QVector2D newVel = Collision2D::applyBounce(
                    vel, earliestContact.normal,
                    body->bounceFactor(), body->slideFactor());
                body->setVelocity(newVel);
            }
        }
    }

    // 3. Détection statique aux positions corrigées (gère les contacts au repos, les coins)
    QVector<CollisionResult> contacts;
    for (PattounX_body* body : m_bodies) {
        if (!body->collisionEnabled() || body->isStatic() || body->isSleeping()) continue;

        for (PattounX_zone* zone : m_zones) {
            if (!zone->isActive() || !zone->exclusion()) continue;

            QVector<CollisionResult> results = zone->checkCollisionAll(body->position(), body->collisionRadius());

            for (CollisionResult& result : results) {
                result.body = body;
                contacts.append(result);
                collidedPairs.insert(qMakePair(body, result.zone));
            }
        }
    }

    // 4. Solver itératif pour les contacts statiques résiduels
    for (int i = 0; i < VELOCITY_ITERATIONS; ++i) {
        resolveCollisions(contacts, dt);
    }

    // 5. Correction de position (anti-pénétration)
    correctPositions(contacts);

    // 6. Émettre les signaux de collision (dédupliqués par paire body/zone)
    for (const auto& pair : collidedPairs) {
        emit bodyCollided(pair.first, pair.second);
        emit pair.first->collisionOccurred(pair.second);
    }
}

void PattounX_engine::updateBody(PattounX_body* body, qreal dt)
{
    if (!body || body->isStatic()) return;

    applyGroundFrictionAndZones(body, dt);

    // Intégrer (Vitesse += Force; Pos += Vitesse)
    body->integrate(dt);
}

// applyZoneEffects was merged into applyGroundFrictionAndZones

void PattounX_engine::resolveCollisions(const QVector<CollisionResult>& contacts, qreal dt)
{
    for (const CollisionResult& m : contacts) {
        PattounX_body* A = m.body;
        // B est la zone (Mur), masse infinie, vitesse nulle.

        QVector2D rv = A->velocity(); // Vitesse relative (V_body - 0)
        QVector2D normal = m.normal;

        // --- 1. Vitesse le long de la normale ---
        qreal velAlongNormal = QVector2D::dotProduct(rv, normal);

        // Ne pas résoudre si les objets s'éloignent déjà
        if (velAlongNormal > 0) continue;

        // --- 2. Impulsion Normale (Rebond) ---
        qreal e = A->restitution(); // Coefficient de restitution

        // Formule : j = -(1+e)*V_rel_norm / invMass
        qreal j = -(1.0 + e) * velAlongNormal;
        j /= A->invMass(); // + 0 pour le mur

        QVector2D impulse = j * normal;

        // Appliquer l'impulsion normale
        A->setVelocity(A->velocity() + impulse * A->invMass());

        // --- 3. Friction (Impulsion Tangente) ---
        // Recalculer la vitesse relative après le rebond
        rv = A->velocity();

        // Trouver la tangente : V_t = V - (V . n) * n
        QVector2D tangent = rv - QVector2D::dotProduct(rv, normal) * normal;

        // Normaliser la tangente
        if (tangent.lengthSquared() > 0.00001) {
            tangent.normalize();
        } else {
            continue; // Pas de friction si pas de mouvement tangentiel
        }

        // Calculer magnitude friction (jt) - Même formule que normale, sans restitution
        qreal jt = -QVector2D::dotProduct(rv, tangent);
        jt /= A->invMass();

        // Loi de Coulomb : friction combinée body/zone (moyenne géométrique)
        qreal zoneFriction = 0.5; // défaut
        if (m.zone && m.zone->zoneParameter()) {
            qreal zf = m.zone->zoneParameter()->frictionStrenght();
            if (zf > 0.0) zoneFriction = zf;
        }
        qreal mu = std::sqrt(A->staticFriction() * zoneFriction);

        QVector2D frictionImpulse;
        if (std::abs(jt) < j * mu) {
            // Friction Statique (assez fort pour arrêter)
            frictionImpulse = jt * tangent;
        } else {
            // Friction Dynamique (glissement)
            qreal dynamicMu = std::sqrt(A->dynamicFriction() * zoneFriction);
            frictionImpulse = -j * tangent * dynamicMu;
        }

        // Appliquer la friction
        A->setVelocity(A->velocity() + frictionImpulse * A->invMass());
    }
}
void PattounX_engine::correctPositions(const QVector<CollisionResult>& contacts)
{
    for (const CollisionResult& m : contacts) {
        PattounX_body* A = m.body;

        // Recalculer la pénétration résiduelle par rapport à la position ACTUELLE
        // (qui a pu être déplacée par une correction précédente)
        QVector2D toBody = A->position() - m.closestPoint;
        qreal currentDist = toBody.length();
        qreal residualPenetration = A->collisionRadius() - currentDist;

        if (residualPenetration <= PENETRATION_SLOP) continue;

        qreal correctionMag = (residualPenetration - PENETRATION_SLOP) * POSITION_CORRECTION_PERCENT;
        QVector2D normal = (currentDist > Collision2D::EPSILON) ? toBody / currentDist : m.normal;
        QVector2D correction = normal * correctionMag;

        A->movePosition(A->position() + correction);
    }
}

// resolveCollisions_old removed in favor of iterative solver


// --- Requêtes ---

QVariantList PattounX_engine::getZonesAtPoint(const QVector2D& point) const
{
    QVariantList result;
    
    for (PattounX_zone* zone : m_zones) {
        if (zone->isActive() && zone->containsPoint(point)) {
            result.append(QVariant::fromValue(zone));
        }
    }
    
    return result;
}

void PattounX_engine::applyGroundFrictionAndZones(PattounX_body* body, qreal dt)
{
    QSet<PattounX_zone*> currentZones;
    qreal currentDamping = DEFAULT_GROUND_DAMPING; 
    qreal currentAccelerationMultiplier = 1.0;
    qreal currentSpeedMultiplier = 1.0;

    QVector2D pos = body->position();

    for (PattounX_zone* zone : m_zones) {
        if (!zone->isActive()) continue;

        // Broadphase AABB
        if (!zone->boundingBox().contains(pos.x(), pos.y())) continue;

        if (zone->containsPoint(pos)) {
            currentZones.insert(zone);
            
            // Appliquer les paramètres de la zone
            const ZoneParameter& params = zone->getZoneParameters();
            
            // Damping : on garde le max parmi toutes les zones (Glace=faible, Boue=fort)
            currentDamping = std::max(currentDamping, params.frictionStrenght());
            
            // Boost de vitesse
            if (params.velocityStrenght() > 0) {
                QVector2D force = params.velocityDirection().normalized() * params.velocityStrenght();
                body->applyForce(force);
            }

            // Accumulate acceleration multiplier
            currentAccelerationMultiplier *= params.accelerationMultiplier();
            
            // Accumulate speed multiplier
            currentSpeedMultiplier *= params.speedMultiplier();
        }
    }

    // Appliquer le damping calculé
    body->setLinearDamping(currentDamping);
    body->setZoneAccelerationMultiplier(currentAccelerationMultiplier);
    body->setZoneSpeedMultiplier(currentSpeedMultiplier);

    // Gérer les signaux Entered/Exited
    QSet<PattounX_zone*>& prevZones = m_activeZonesPerBody[body];
    for(auto z : currentZones) { if(!prevZones.contains(z)) { emit bodyEnteredZone(body, z); emit body->enteredZone(z); } }
    for(auto z : prevZones) { if(!currentZones.contains(z)) { emit bodyExitedZone(body, z); emit body->exitedZone(z); } }
    m_activeZonesPerBody[body] = currentZones;
}
