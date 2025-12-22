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

void PhysicsBody2D::applyForce(const QVector2D& inputVector, qreal inputForce)
{
    m_velocity *= inputVector * inputForce;
}
void PhysicsBody2D::addForce(const QVector2D& inputVector, qreal inputForce)
{
    m_velocity += inputVector * inputForce;
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

void PhysicsBody2D::applyDirectionalForce(const QVector2D& force, qreal dt)
{
    // Ajouter directement à la vitesse (tapis roulant)
    m_velocity += force * dt;
    emit velocityChanged();
}

void PhysicsBody2D::applyDirectionalFriction(const QVector2D& frictionDirection, qreal frictionStrength, qreal dt)
{
    if (m_isStatic) return;

    // Normaliser la direction de friction
    QVector2D normalizedDir = frictionDirection.normalized();

    // Calculer la composante de vitesse dans la direction de friction
    qreal velocityAlongFriction = QVector2D::dotProduct(m_velocity, normalizedDir);

    // Appliquer la friction seulement si on se déplace dans cette direction
    if (velocityAlongFriction > 0) {
        qreal frictionForce = frictionStrength * dt;
        qreal reduction = std::min(frictionForce, velocityAlongFriction);
        m_velocity -= normalizedDir * reduction;
        emit velocityChanged();
    }
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


QVector2D PhysicsBody2D::inputVector() const
{
    return m_inputVector;
}

void PhysicsBody2D::setInputVector(const QVector2D &newInputVector)
{
    if (m_inputVector == newInputVector)
        return;
    m_inputVector = newInputVector;
    emit inputVectorChanged();
}

qreal PhysicsBody2D::inputStrenght() const
{
    return m_inputStrenght;
}

void PhysicsBody2D::setInputStrenght(qreal newInputStrenght)
{
    if (qFuzzyCompare(m_inputStrenght, newInputStrenght))
        return;
    m_inputStrenght = newInputStrenght;
    emit inputStrenghtChanged();
}
