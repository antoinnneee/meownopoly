#include "physics2d_engine.h"
#include "game/item_snapable/ItemSnapable.h"
#include "game/item_snapable/polygonParameter.h"
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
    PhysicsZone2D* zone = new PhysicsZone2D(id, type, this);
    m_zones[id] = zone;
    
    if (m_debugMode) {
        qDebug() << "[PhysicsEngine2D] Created zone:" << id << "type:" << type;
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
        PolygonParameter* polygonParam = snapable->polygonParameter();
        
        if (!polygonParam || polygonParam->pointCount() < 3) continue;
        
        // Déterminer le type de zone
        PhysicsZone2D::ZoneType zoneType = PhysicsZone2D::Exclusion;
        
        if (tileType == ItemSnapable::ExclusionZone) {
            zoneType = PhysicsZone2D::Exclusion;
        } else if (tileType == ItemSnapable::EffectZone) {
            // Pour l'instant, EffectZone par défaut est SpeedBoost
            // On pourrait étendre PolygonParameter pour stocker le type d'effet
            zoneType = PhysicsZone2D::SpeedBoost;
        } else {
            continue; // Ignorer les autres types
        }
        
        // Créer la zone
        QString zoneId = QString("zone_%1").arg(zoneIndex++);
        PhysicsZone2D* zone = createZone(zoneId, static_cast<int>(zoneType));
        
        // Copier les propriétés
        zone->setPolygon(polygonParam->polygonPoints());
        zone->setZoneName(polygonParam->zoneName());
        zone->setZoneColor(polygonParam->zoneColor());
        
        if (m_debugMode) {
            qDebug() << "[PhysicsEngine2D] Loaded zone from snapable:"
                     << zoneId << "type:" << zoneType
                     << "points:" << polygonParam->pointCount();
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
    
    // 1. Appliquer les effets des zones
    applyZoneEffects(body, dt);
    
    // 2. Calculer la nouvelle position proposée
    QVector2D newPos = body->position() + body->velocity() * dt;

    
    // 3. Détecter et résoudre les collisions
    if (body->collisionEnabled()) {
        resolveCollisions(body, dt, newPos);
    }
    else {
        body->setPosition(newPos);
    }
    
    // 4. Mettre à jour la position finale
    updateBodyPosition(body, dt);
}

void PhysicsEngine2D::applyZoneEffects(PhysicsBody2D* body, qreal dt)
{
    QVector2D pos = body->position();
    QSet<PhysicsZone2D*> currentZones;
    
    for (PhysicsZone2D* zone : m_zones) {
        if (!zone->isActive()) continue;
        
        // Ignorer les zones d'exclusion pour les effets (elles sont gérées par collision)
        if (zone->zoneType() == PhysicsZone2D::Exclusion) continue;
        
        if (zone->containsPoint(pos)) {
            currentZones.insert(zone);
            
            // Appliquer l'effet selon le type
            switch (zone->zoneType()) {
                case PhysicsZone2D::SpeedBoost:
                case PhysicsZone2D::SpeedSlow:
                    body->applySpeedModifier(zone->getEffectMultiplier());
                    break;
                    
                case PhysicsZone2D::IceZone:
                    body->applyFrictionModifier(zone->getFrictionModifier());
                    break;
                    
                case PhysicsZone2D::ConveyorBelt:
                    body->applyDirectionalForce(
                        zone->effectDirection() * zone->effectStrength(),
                        dt
                    );
                    break;
                    
                case PhysicsZone2D::JumpPad:
                    // TODO: Implémenter si nécessaire (impulsion unique)
                    break;
                    
                default:
                    break;
            }
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
//    QVector2D newPos = body->position() + velocity * dt;
    bool collisionOccurred = false;
    QVector2D collisionNormal;
    
    // Tester contre toutes les zones d'exclusion
    for (PhysicsZone2D* zone : std::as_const(m_zones)) {
        if (!zone->isActive() || zone->zoneType() != PhysicsZone2D::Exclusion) {
            continue;
        }
        
        CollisionResult result = zone->checkCollision(newPos, body->collisionRadius());
        
        if (result.colliding) {
            collisionOccurred = true;
            collisionNormal = result.normal;
            
            if (m_debugMode) {
                qDebug() << "[PhysicsEngine2D] Collision:"
                         << "body:" << body->bodyId()
                         << "zone:" << zone->zoneId()
                         << "normal:" << result.normal
                         << "penetration:" << result.penetration;
            }
            
            // Appliquer le rebond
            QVector2D newVelocity = Collision2D::applyBounce(
                velocity,
                result.normal,
                body->bounceFactor(),
                body->slideFactor()
            );
            
            body->setVelocity(newVelocity);
            velocity = newVelocity;
            
            // Émettre les signaux
            emit bodyCollided(body, zone);
            emit body->collisionOccurred(zone);
            
            // Recalculer la nouvelle position avec la vitesse après rebond
            newPos = body->position() + velocity * dt;
        }
    }
    
    // Mettre à jour l'état de collision
    body->setCollidingState(collisionOccurred, collisionNormal);
}

void PhysicsEngine2D::updateBodyPosition(PhysicsBody2D* body, qreal dt)
{
    QVector2D newPos = body->position() + body->velocity() * dt;
    body->setPosition(newPos);
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
        if (!zone->isActive() || zone->zoneType() != PhysicsZone2D::Exclusion) {
            continue;
        }
        
        CollisionResult result = zone->checkCollision(center, radius);
        if (result.colliding) {
            return true;
        }
    }
    
    return false;
}

