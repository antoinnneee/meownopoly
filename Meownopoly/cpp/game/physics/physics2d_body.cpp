#include "physics2d_body.h"
#include "physics2d_engine.h"
#include <cmath>
#include <algorithm>

PhysicsBody2D::PhysicsBody2D(QObject* parent)
    : QObject(parent)
    , m_bodyId("")
{
}

PhysicsBody2D::PhysicsBody2D(const QString& id, QObject* parent)
    : QObject(parent)
    , m_bodyId(id)
{
}

// --- Setters ---

void PhysicsBody2D::setPosition(const QVector2D& pos)
{
    if (m_position != pos) {
        m_position = pos;
        emit positionChanged();
    }
}

void PhysicsBody2D::setVelocity(const QVector2D& vel)
{
    if (m_velocity != vel) {
        m_velocity = vel;
        emit velocityChanged();
    }
}

void PhysicsBody2D::setCollisionRadius(qreal radius)
{
    if (!qFuzzyCompare(m_collisionRadius, radius)) {
        m_collisionRadius = radius;
        emit collisionRadiusChanged();
    }
}

void PhysicsBody2D::setBounceFactor(qreal factor)
{
    if (!qFuzzyCompare(m_bounceFactor, factor)) {
        m_bounceFactor = std::clamp(factor, 0.0, 1.0);
        emit bounceFactorChanged();
    }
}

void PhysicsBody2D::setSlideFactor(qreal factor)
{
    if (!qFuzzyCompare(m_slideFactor, factor)) {
        m_slideFactor = std::clamp(factor, 0.0, 1.0);
        emit slideFactorChanged();
    }
}

void PhysicsBody2D::setAcceleration(qreal accel)
{
    if (!qFuzzyCompare(m_acceleration, accel)) {
        m_acceleration = accel;
        emit accelerationChanged();
    }
}

void PhysicsBody2D::setMaxSpeed(qreal speed)
{
    if (!qFuzzyCompare(m_maxSpeed, speed)) {
        m_maxSpeed = speed;
        emit maxSpeedChanged();
    }
}

void PhysicsBody2D::setMass(qreal mass)
{
    if (!qFuzzyCompare(m_mass, mass)) {
        m_mass = std::max(0.01, mass);
        emit massChanged();
    }
}

void PhysicsBody2D::setIsStatic(bool isStatic)
{
    if (m_isStatic != isStatic) {
        m_isStatic = isStatic;
        emit isStaticChanged();
    }
}

void PhysicsBody2D::setCollisionEnabled(bool enabled)
{
    if (m_collisionEnabled != enabled) {
        m_collisionEnabled = enabled;
        emit collisionEnabledChanged();
    }
}

// --- API Publique ---

void PhysicsBody2D::applyForce(const QVector2D& inputForce, qreal dt)
{
    if (m_isStatic) return;
    
    // Calculer la vitesse cible basée sur l'input
    qreal targetSpeed = m_maxSpeed * m_currentSpeedModifier;
    QVector2D targetVelocity(0, 0);
    
    if (inputForce.length() > 0.0001f) {
        QVector2D inputDir = inputForce.normalized();
        targetVelocity = inputDir * targetSpeed;
    }
    
    // Appliquer l'accélération vers la vitesse cible
    QVector2D velocityDiff = targetVelocity - m_velocity;
    qreal accelThisFrame = m_acceleration * dt;
    
    // Cast explicite en qreal pour éviter les conflits float/double avec std::min
    qreal diffX = static_cast<qreal>(std::abs(velocityDiff.x()));
    qreal diffY = static_cast<qreal>(std::abs(velocityDiff.y()));
    
    QVector2D accelForce(
        std::copysign(std::min(diffX, accelThisFrame), static_cast<qreal>(velocityDiff.x())),
        std::copysign(std::min(diffY, accelThisFrame), static_cast<qreal>(velocityDiff.y()))
    );
    
    m_velocity += accelForce;
    
    // Appliquer la friction quand pas d'input
    if (inputForce.length() < 0.0001f && m_engine) {
        qreal friction = m_engine->friction() * m_currentFrictionModifier;
        qreal frictionForce = friction * dt;
        qreal velLen = m_velocity.length();
        
        if (velLen > 0.0001f) {
            qreal reduction = std::min(frictionForce, velLen);
            qreal factor = (velLen - reduction) / velLen;
            m_velocity *= factor;
        }
    }
    
    // Réinitialiser les modificateurs pour le prochain frame
    m_currentSpeedModifier = 1.0;
    m_currentFrictionModifier = 1.0;
    
    emit velocityChanged();
}

void PhysicsBody2D::applyImpulse(const QVector2D& impulse)
{
    if (m_isStatic) return;
    
    // Impulsion = changement instantané de vitesse (divisé par masse)
    m_velocity += impulse / m_mass;
    emit velocityChanged();
}
void PhysicsBody2D::stop()
{
    m_velocity = QVector2D(0, 0);
    emit velocityChanged();
}

void PhysicsBody2D::reset()
{
    m_velocity = QVector2D(0, 0);
    m_isColliding = false;
    m_lastCollisionNormal = QVector2D(0, 0);
    m_currentSpeedModifier = 1.0;
    m_currentFrictionModifier = 1.0;
    
    emit velocityChanged();
    emit isCollidingChanged();
    emit lastCollisionNormalChanged();
}

// --- Usage interne ---

void PhysicsBody2D::applySpeedModifier(qreal modifier)
{
    m_currentSpeedModifier *= modifier;
}

void PhysicsBody2D::applyFrictionModifier(qreal modifier)
{
    m_currentFrictionModifier *= modifier;
}

void PhysicsBody2D::applyDirectionalForce(const QVector2D& force, qreal dt)
{
    if (m_isStatic) return;
    
    // Ajouter directement à la vitesse (tapis roulant)
    m_velocity += force * dt;
    emit velocityChanged();
}

void PhysicsBody2D::setCollidingState(bool colliding, const QVector2D& normal)
{
    bool groundedChanged = (m_isColliding != colliding);
    bool normalChanged = (m_lastCollisionNormal != normal);
    
    m_isColliding = colliding;
    m_lastCollisionNormal = normal;
    
    if (groundedChanged) emit isCollidingChanged();
    if (normalChanged) emit lastCollisionNormalChanged();
}

