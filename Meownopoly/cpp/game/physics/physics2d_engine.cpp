#include "physics2d_engine.h"
#include "game/item_snapable/ItemSnapable.h"
#include "game/item_snapable/ZoneParameter.h"
#include <QDebug>
#include <QtQml>

void PhysicsEngine2D::registerQml()
{
    qmlRegisterType<PhysicsEngine2D>("PhysicsEngine", 1, 0, "PhysicsEngine2D");
    qmlRegisterType<PhysicsBody2D>("PhysicsEngine", 1, 0, "PhysicsBody2D");
    qmlRegisterType<PhysicsZone2D>("PhysicsEngine", 1, 0, "PhysicsZone2D");
    
    // Enregistrer l'enum ZoneType pour QML
    qmlRegisterUncreatableMetaObject(
        PhysicsZone2D::staticMetaObject,
        "PhysicsEngine", 1, 0,
        "ZoneType",
        "Error: ZoneType is an enum"
    );
}

PhysicsEngine2D::PhysicsEngine2D(QObject* parent)
    : QObject(parent)
{
}

PhysicsEngine2D::~PhysicsEngine2D()
{
    clearBodies();
    clearZones();
}

// --- Setters ---

void PhysicsEngine2D::setFriction(qreal friction)
{
    if (!qFuzzyCompare(m_friction, friction)) {
        m_friction = std::max(0.0, friction);
        emit frictionChanged();
    }
}

void PhysicsEngine2D::setEnabled(bool enabled)
{
    if (m_enabled != enabled) {
        m_enabled = enabled;
        emit enabledChanged();
    }
}

void PhysicsEngine2D::setDebugMode(bool debug)
{
    if (m_debugMode != debug) {
        m_debugMode = debug;
        emit debugModeChanged();
    }
}

// --- Gestion des Bodies ---

PhysicsBody2D* PhysicsEngine2D::createBody(const QString& id)
{
    if (m_bodies.contains(id)) {
        qWarning() << "[PhysicsEngine2D] Body with id" << id << "already exists";
        return m_bodies[id];
    }
    
    PhysicsBody2D* body = new PhysicsBody2D(id, this);
    body->setEngine(this);
    m_bodies[id] = body;
    
    if (m_debugMode) {
        qDebug() << "[PhysicsEngine2D] Created body:" << id;
    }
    
    emit bodyCountChanged();
    return body;
}

bool PhysicsEngine2D::removeBody(const QString& id)
{
    if (!m_bodies.contains(id)) {
        return false;
    }
    
    PhysicsBody2D* body = m_bodies.take(id);
    m_activeZonesPerBody.remove(body);
    body->deleteLater();
    
    if (m_debugMode) {
        qDebug() << "[PhysicsEngine2D] Removed body:" << id;
    }
    
    emit bodyCountChanged();
    return true;
}

PhysicsBody2D* PhysicsEngine2D::getBody(const QString& id) const
{
    return m_bodies.value(id, nullptr);
}

void PhysicsEngine2D::clearBodies()
{
    for (PhysicsBody2D* body : m_bodies) {
        body->deleteLater();
    }
    m_bodies.clear();
    m_activeZonesPerBody.clear();
    emit bodyCountChanged();
}

// --- Gestion des Zones ---

PhysicsZone2D* PhysicsEngine2D::createZone(const QString& id, int zoneType)
{
    if (m_zones.contains(id)) {
        qWarning() << "[PhysicsEngine2D] Zone with id" << id << "already exists";
        return m_zones[id];
    }

    PhysicsZone2D::ZoneType type = static_cast<PhysicsZone2D::ZoneType>(zoneType);
    PhysicsZone2D* zone = new PhysicsZone2D(id, this);
    m_zones[id] = zone;

    if (m_debugMode) {
        qDebug() << "[PhysicsEngine2D] Created zone:" << id << "type:" << type;
    }

    emit zoneCountChanged();
    return zone;
}

PhysicsZone2D* PhysicsEngine2D::createZone(const QString& id, ZoneParameter *zoneParam)
{
    if (m_zones.contains(id)) {
        qWarning() << "[PhysicsEngine2D] Zone with id" << id << "already exists";
        return m_zones[id];
    }

    PhysicsZone2D* zone = new PhysicsZone2D(id, *zoneParam, this);
    m_zones[id] = zone;

    if (m_debugMode) {
        qDebug() << "[PhysicsEngine2D] Created zone:" << id;
    }

    emit zoneCountChanged();
    return zone;
}

bool PhysicsEngine2D::removeZone(const QString& id)
{
    if (!m_zones.contains(id)) {
        return false;
    }
    
    PhysicsZone2D* zone = m_zones.take(id);
    
    // Nettoyer les références dans activeZonesPerBody
    for (auto& activeZones : m_activeZonesPerBody) {
        activeZones.remove(zone);
    }
    
    zone->deleteLater();
    
    if (m_debugMode) {
        qDebug() << "[PhysicsEngine2D] Removed zone:" << id;
    }
    
    emit zoneCountChanged();
    return true;
}

PhysicsZone2D* PhysicsEngine2D::getZone(const QString& id) const
{
    return m_zones.value(id, nullptr);
}

void PhysicsEngine2D::clearZones()
{
    for (PhysicsZone2D* zone : m_zones) {
        zone->deleteLater();
    }
    m_zones.clear();
    
    // Vider les zones actives
    for (auto& activeZones : m_activeZonesPerBody) {
        activeZones.clear();
    }
    
    emit zoneCountChanged();
}

void PhysicsEngine2D::setZonesFromSnapables(const QVariantList& snapables)
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
        PhysicsZone2D::ZoneType zoneType = PhysicsZone2D::Zone_Exclusion;
        
        if (tileType == ItemSnapable::PhysicZoneTile) {
            zoneType = PhysicsZone2D::Zone_Exclusion;
        } else if (tileType == ItemSnapable::PhysicZoneTile) {
            // Pour l'instant, EffectZone par défaut est SpeedBoost
            // On pourrait étendre ZoneParameter pour stocker le type d'effet
            zoneType = PhysicsZone2D::Zone_Speed;
        } else {
            continue; // Ignorer les autres types
        }
        
        // Créer la zone
        QString zoneId = QString("zone_%1").arg(zoneIndex++);
        PhysicsZone2D* zone = createZone(zoneId, zoneParam);

        // // Copier les propriétés
        // zone->setPolygon(zoneParam->polygonPoints());
        // zone->setZoneName(zoneParam->zoneName());
        // zone->setZoneColor(zoneParam->zoneColor());

        if (m_debugMode) {
            qDebug() << "[PhysicsEngine2D] Loaded zone from snapable:"
                     << zoneId << "type:" << zoneType
                     << "points:" << zoneParam->pointCount();
        }
    }
    
    if (m_debugMode) {
        qDebug() << "[PhysicsEngine2D] Loaded" << m_zones.size() << "zones from snapables";
    }
}

// --- Simulation ---

void PhysicsEngine2D::updateAll(qreal dt)
{
    if (!m_enabled || dt <= 0) return;
    
    for (PhysicsBody2D* body : m_bodies) {
        updateBody(body, dt);
    }
}

void PhysicsEngine2D::updateBody(PhysicsBody2D* body, qreal dt)
{
    if (!body || body->isStatic()) return;
        // Gérer les zones (glace, boue, boosts) AVANT l'intégration

    applyGroundFrictionAndZones(body, dt);
    // Intégrer (Vitesse += Force; Pos += Vitesse)
    body->integrate(dt);

    /*
    // 3. Détecter et résoudre les collisions
    if (body->collisionEnabled()) {
        // body->setPosition(newPos);
        resolveCollisions(body, dt, newPos);
    }
    else {
        body->setPosition(newPos);
    }
    */

}

void  PhysicsEngine2D::applyWorldEffect(PhysicsBody2D* body, qreal dt)
{

    // Appliquer l'input du body

    body->applyForce(QVector2D(1,1), (1.-m_friction));

}

void PhysicsEngine2D::applyZoneEffects(PhysicsBody2D* body, qreal dt)
{
    QVector2D pos = body->position();
    QSet<PhysicsZone2D*> currentZones;

    for (PhysicsZone2D* zone : m_zones) {
        if (!zone->isActive()) continue;
        
        // Ignorer les zones d'exclusion pour les effets (elles sont gérées par collision)
        // if (zone->zoneType() == PhysicsZone2D::Exclusion) continue;
        
        if (zone->containsPoint(pos)) {
            currentZones.insert(zone);

            // Appliquer les effets basés sur les paramètres de la zone
            const ZoneParameter& params = zone->getZoneParameters();

            // // Appliquer la force directionnelle si définie
            // if (params.velocityStrenght() > 0) {
            //     QVector2D force = params.velocityDirection().normalized() * params.velocityStrenght();
            //     body->applyZoneForce(force, dt, zone->zoneId());
            // }

            // // Appliquer le multiplicateur de vitesse
            // if (params.speedMultiplier() != 1.0) {
            //     body->applyZoneSpeedMultiplier(params.speedMultiplier(), zone->zoneId());
            // }

            // // Appliquer la friction directionnelle si définie
            // if (params.frictionStrenght() > 0) {
            //     body->applyDirectionalFriction(params.frictionDirection(), params.frictionStrenght(), dt);
            // }
        }
    }
    
    // Détecter entrées/sorties de zones
    QSet<PhysicsZone2D*>& previousZones = m_activeZonesPerBody[body];
    
    // Zones entrées
    for (PhysicsZone2D* zone : currentZones) {
        if (!previousZones.contains(zone)) {
            qDebug() << "[PhysicsEngine2D] Body entered zone:" << body->bodyId() << "zone:" << zone->zoneId();
            emit bodyEnteredZone(body, zone);
            emit body->enteredZone(zone);
        }
    }
    
    // Zones sorties
    for (PhysicsZone2D* zone : previousZones) {
        if (!currentZones.contains(zone)) {
            qDebug() << "[PhysicsEngine2D] Body exited zone:" << body->bodyId() << "zone:" << zone->zoneId();
            emit bodyExitedZone(body, zone);
            emit body->exitedZone(zone);
        }
    }
    
    previousZones = currentZones;
}

void PhysicsEngine2D::resolveCollisions(PhysicsBody2D* body, qreal dt, QVector2D newPos)
{
    QVector2D velocity = body->velocity();
    QVector2D currentPos = body->position();
    bool collisionOccurred = false;
    QVector2D collisionNormal;

    // Approche hybride : tester plusieurs positions intermédiaires pour éviter le tunneling
    // tout en gardant la logique simple de collision discrète

    // Calculer le nombre d'étapes d'interpolation basé sur la longueur du mouvement
    // Plus le mouvement est long (vitesse élevée), plus d'étapes pour éviter le tunneling
    QVector2D movement = newPos - currentPos;
    qreal movementLength = movement.length();
    qreal colRad = body->collisionRadius();

    // qDebug() << "[PhysicsEngine2D] Movement length:" << movementLength << "collision radius:" << body->collisionRadius() << velocity;

    QVector2D bestCollisionPos = newPos;
    CollisionResult bestResult;

        // Tester contre toutes les zones d'exclusion
    for (PhysicsZone2D* zone : std::as_const(m_zones)) {
        if (!zone->isActive() || !zone->exclusion()) {
            continue;
        }

        CollisionResult result = zone->checkCollisionSweep(currentPos, newPos, body->collisionRadius());

        if (result.colliding) {
            qDebug() << "collision occured = true";
            bestCollisionPos = newPos;
            bestResult = result;
            bestResult.zone = zone;
            collisionOccurred = true;
            break;
        }
    }
    

    // Si collision trouvée, appliquer le rebond
    if (collisionOccurred) {
        collisionNormal = bestResult.normal;

        // Appliquer le rebond
        QVector2D newVelocity = Collision2D::applyBounce(
            velocity,
            bestResult.normal,
            body->bounceFactor(),
            body->slideFactor()
        );

        if (m_debugMode) {
            qDebug() << "[PhysicsEngine2D] Collision detected at t:"
                     << "body:" << body->bodyId()
                     << "zone:" << bestResult.zone->zoneId()
                     << "normal:" << bestResult.normal
                     << "penetration:" << bestResult.penetration
                    << "new velocity:" << newVelocity;
        }

        body->setVelocity(newVelocity);

        // Positionner le body à l'extérieur de la zone en utilisant la normale et la pénétration
        QVector2D correctedPosition = currentPos + bestResult.normal * bestResult.penetration;
        body->setPosition(correctedPosition);

        // Émettre les signaux
        emit bodyCollided(body, bestResult.zone);
        emit body->collisionOccurred(bestResult.zone);
    } else {
        // Pas de collision, mettre à jour normalement
        body->setPosition(newPos);
    }

    // Mettre à jour l'état de collision
    body->setCollidingState(collisionOccurred, collisionNormal);
}


// --- Requêtes ---

QVariantList PhysicsEngine2D::getZonesAtPoint(const QVector2D& point) const
{
    QVariantList result;
    
    for (PhysicsZone2D* zone : m_zones) {
        if (zone->isActive() && zone->containsPoint(point)) {
            result.append(QVariant::fromValue(zone));
        }
    }
    
    return result;
}

bool PhysicsEngine2D::checkCollisionAt(const QVector2D& center, qreal radius) const
{
    for (PhysicsZone2D* zone : m_zones) {
        if (!zone->isActive() || !zone->exclusion()) {
            continue;
        }
        
        CollisionResult result = zone->checkCollision(center, radius);
        if (result.colliding) {
            return true;
        }
    }
    
    return false;
}

void PhysicsEngine2D::applyGroundFrictionAndZones(PhysicsBody2D* body, qreal dt)
{
    QSet<PhysicsZone2D*> currentZones;
    qreal defaultDamping = 0.05; // Sol standard (Terre)
    qreal currentDamping = defaultDamping; 

    QVector2D pos = body->position();

    for (PhysicsZone2D* zone : m_zones) {
        if (!zone->isActive()) continue;
        
        // Optimisation possible : AABB check avant containsPoint
        if (zone->containsPoint(pos)) {
            currentZones.insert(zone);
            
            // Appliquer les paramètres de la zone
            const ZoneParameter& params = zone->getZoneParameters();
            
            // Modifier le damping (Glace = damping faible, Boue = damping fort)
            // On pourrait stocker le damping dans ZoneParameter (ex: frictionStrength)
            if (params.frictionStrenght() > 0) {
                 // Si c'est une zone de friction (ex: boue), on remplace le damping
                 // Si frictionStrength = 0 (Glace), damping proche de 0
                 currentDamping = params.frictionStrenght(); 
            }
            
            // Boost de vitesse (Tapis roulant)
            if (params.velocityStrenght() > 0) {
                QVector2D force = params.velocityDirection().normalized() * params.velocityStrenght();
                body->applyForce(force);
            }
        }
    }

    // Appliquer le damping calculé
    body->setLinearDamping(currentDamping);

    // Gérer les signaux Entered/Exited
    QSet<PhysicsZone2D*>& prevZones = m_activeZonesPerBody[body];
    for(auto z : currentZones) { if(!prevZones.contains(z)) { emit bodyEnteredZone(body, z); emit body->enteredZone(z); } }
    for(auto z : prevZones) { if(!currentZones.contains(z)) { emit bodyExitedZone(body, z); emit body->exitedZone(z); } }
    m_activeZonesPerBody[body] = currentZones;
}
