#include "pattounx_engine.h"
#include "game/item_snapable/ItemSnapable.h"
#include "game/item_snapable/ZoneParameter.h"
#include <QDebug>
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

PattounX_zone* PattounX_engine::createZone(const QString& id)
{
    if (m_zones.contains(id)) {
        qWarning() << "[PattounX_engine] Zone with id" << id << "already exists";
        return m_zones[id];
    }

    PattounX_zone* zone = new PattounX_zone(id, this);
    m_zones[id] = zone;

    if (m_debugMode) {
        qDebug() << "[PattounX_engine] Created zone:" << id;
    }

    emit zoneCountChanged();
    return zone;
}

PattounX_zone* PattounX_engine::createZone(const QString& id, ZoneParameter *zoneParam)
{
    if (m_zones.contains(id)) {
        qWarning() << "[PattounX_engine] Zone with id" << id << "already exists";
        return m_zones[id];
    }

    PattounX_zone* zone = new PattounX_zone(id, *zoneParam, this);
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
    
    int zoneIndex = 0;
    
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
        QString zoneId = QString("zone_%1").arg(zoneIndex++);
        PattounX_zone* zone = createZone(zoneId, zoneParam);

        if (m_debugMode) {
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
    
    for (PattounX_body* body : m_bodies) {
        updateBody(body, dt);
    }
    // 2. Détection des collisions (Broadphase + Narrowphase CCD)
    QVector<CollisionResult> contacts;
    for (PattounX_body* body : m_bodies) {
        if (!body->collisionEnabled() || body->isStatic()) continue;

        for (PattounX_zone* zone : m_zones) {
            if (!zone->isActive() || !zone->exclusion()) continue;

            // Utilisation collision sweep pour détecter TOUS les segments impactés
            QVector<CollisionResult> results = zone->checkCollisionSweepAll(body->previousPosition(), body->position(), body->collisionRadius());

            for (CollisionResult& result : results) {
                result.body = body;
                
                // Si c'est une collision par balayage (t < 1.0), on calcule la pénétration totale
                // La pénétration doit pousser le body à l'extérieur de la surface d'impact
                if (result.t < 1.0) {
                    QVector2D impactPos = body->previousPosition() + result.t * (body->position() - body->previousPosition());
                    QVector2D penetrationVec = body->position() - impactPos;
                    qreal depth = QVector2D::dotProduct(penetrationVec, -result.normal);
                    
                    // La pénétration totale est la profondeur de tunneling + un petit buffer
                    result.penetration = std::max(result.penetration, depth + TUNNELING_BUFFER);
                }
                
                contacts.append(result);
            }
        }
    }

    // 3. Résolution des collisions (Solver Itératif)
    // On répète plusieurs fois pour stabiliser les empilements ou coins
    for (int i = 0; i < VELOCITY_ITERATIONS; ++i) {
        resolveCollisions(contacts, dt);
    }
    // 4. Correction de position (Anti-pénétration / Anti-jitter)
    correctPositions(contacts);
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

        // Loi de Coulomb : Clamper la friction
        // On utilise l'impulsion normale 'j' comme force de pression
        qreal mu = std::sqrt(std::pow(A->staticFriction(), 2) + 0.5*0.5); // 0.5 pour le mur par défaut

        QVector2D frictionImpulse;
        if (std::abs(jt) < j * mu) {
            // Friction Statique (Assez fort pour arrêter)
            frictionImpulse = jt * tangent;
        } else {
            // Friction Dynamique (Glissement)
            qreal dynamicMu = std::sqrt(std::pow(A->dynamicFriction(), 2) + 0.3*0.3);
            frictionImpulse = -j * tangent * dynamicMu;
        }

        // Appliquer la friction
        A->setVelocity(A->velocity() + frictionImpulse * A->invMass());

        // Signaux de collision
        emit bodyCollided(A, m.zone);
        emit A->collisionOccurred(m.zone);
    }
}
void PattounX_engine::correctPositions(const QVector<CollisionResult>& contacts)
{

    for (const CollisionResult& m : contacts) {
        PattounX_body* A = m.body;

        // La pénétration a été ajustée dans updateAll pour les sweeps
        qreal correctionMag = std::max(m.penetration - PENETRATION_SLOP, 0.0) * POSITION_CORRECTION_PERCENT;
        QVector2D correction = m.normal * correctionMag;

        A->setPosition(A->position() + correction);
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

    QVector2D pos = body->position();

    for (PattounX_zone* zone : m_zones) {
        if (!zone->isActive()) continue;
        
        // Optimisation possible : AABB check avant containsPoint
        if (zone->containsPoint(pos)) {
            currentZones.insert(zone);
            
            // Appliquer les paramètres de la zone
            const ZoneParameter& params = zone->getZoneParameters();
            
            // Modifier le damping (Glace = damping faible, Boue = damping fort)
            // if (params.frictionStrenght() > 0) {
                 // Si c'est une zone de friction (ex: boue)
                 // Si frictionStrength = 0 (Glace)
                 currentDamping = params.frictionStrenght(); 
            // }
            
            // Boost de vitesse
            if (params.velocityStrenght() > 0) {
                QVector2D force = params.velocityDirection().normalized() * params.velocityStrenght();
                body->applyForce(force);
            }

            // Accumulate acceleration multiplier
            currentAccelerationMultiplier *= params.accelerationMultiplier();
        }
    }

    // Appliquer le damping calculé
    body->setLinearDamping(currentDamping);
    body->setZoneAccelerationMultiplier(currentAccelerationMultiplier);

    // Gérer les signaux Entered/Exited
    QSet<PattounX_zone*>& prevZones = m_activeZonesPerBody[body];
    for(auto z : currentZones) { if(!prevZones.contains(z)) { emit bodyEnteredZone(body, z); emit body->enteredZone(z); } }
    for(auto z : prevZones) { if(!currentZones.contains(z)) { emit bodyExitedZone(body, z); emit body->exitedZone(z); } }
    m_activeZonesPerBody[body] = currentZones;
}
