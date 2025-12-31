#include "pattounx_body.h"
#include "pattounx_engine.h"
#include <cmath>
#include <algorithm>

PattounX_body::PattounX_body(QObject* parent)
    : QObject(parent)
    , m_bodyId("")
{
}

PattounX_body::PattounX_body(const QString& id, QObject* parent)
    : QObject(parent)
    , m_bodyId(id)
{
}

// --- Setters ---

void PattounX_body::setPosition(const QVector2D& pos)
{
    if (m_position != pos) {
        m_position = pos;
        m_previousPosition = pos; // Reset previous position to avoid artifact sweeps
        emit positionChanged();
    }
}

void PattounX_body::setVelocity(const QVector2D& vel)
{
    if (m_velocity != vel) {
        m_velocity = vel;
        emit velocityChanged();
    }
}

void PattounX_body::setCollisionRadius(qreal radius)
{
    if (!qFuzzyCompare(m_collisionRadius, radius)) {
        m_collisionRadius = radius;
        emit collisionRadiusChanged();
    }
}

void PattounX_body::setBounceFactor(qreal factor)
{
    if (!qFuzzyCompare(m_bounceFactor, factor)) {
        m_bounceFactor = std::clamp(factor, 0.0, 1.0);
        emit bounceFactorChanged();
    }
}

void PattounX_body::setSlideFactor(qreal factor)
{
    if (!qFuzzyCompare(m_slideFactor, factor)) {
        m_slideFactor = std::clamp(factor, 0.0, 1.0);
        emit slideFactorChanged();
    }
}

void PattounX_body::setAcceleration(qreal accel)
{
    if (!qFuzzyCompare(m_acceleration, accel)) {
        m_acceleration = accel;
        emit accelerationChanged();
    }
}

void PattounX_body::setMaxSpeed(qreal speed)
{
    if (!qFuzzyCompare(m_maxSpeed, speed)) {
        m_maxSpeed = speed;
        emit maxSpeedChanged();
    }
}

void PattounX_body::setMass(qreal mass)
{
    if (!qFuzzyCompare(m_mass, mass)) {
        m_mass = std::max(0.01, mass);
        emit massChanged();
    }
}

void PattounX_body::setIsStatic(bool isStatic)
{
    if (m_isStatic != isStatic) {
        m_isStatic = isStatic;
        emit isStaticChanged();
    }
}

void PattounX_body::setCollisionEnabled(bool enabled)
{
    if (m_collisionEnabled != enabled) {
        m_collisionEnabled = enabled;
        emit collisionEnabledChanged();
    }
}

// --- API Publique ---
void PattounX_body::applyForce(const QVector2D& inputVector, qreal inputForce) {
    applyForce(inputVector * inputForce);
}

void PattounX_body::applyForce(const QVector2D& force)
{
    // On ajoute directement à l'accumulateur ou à la vitesse si intégration Euler simple
    if (m_isStatic) return;
        m_forceAccumulator += force;
}


void PattounX_body::applyImpulse(const QVector2D& impulse)
{
    if (m_isStatic) return;
        m_velocity += impulse * m_invMass;
    emit velocityChanged();
}

void PattounX_body::setLinearDamping(qreal damping)
{
    m_linearDamping = damping;
}

void PattounX_body::stop() {
    m_velocity = QVector2D(0,0);
    m_forceAccumulator = QVector2D(0,0);
    emit velocityChanged();
}

void PattounX_body::reset() {
    stop();
}
// --- Usage intern

void PattounX_body::integrate(qreal dt) {
    if (m_isStatic || dt <= 0) return;

    m_previousPosition = m_position;

    if (m_inputVector.length() > 0.01) {
        // 1. Calcul de la vitesse cible
        QVector2D targetVelocity = m_inputVector * m_maxSpeed;
        
        // 2. On tend vers cette vitesse selon l'accélération
        m_velocity += (targetVelocity - m_velocity) * std::min(1.0, m_acceleration * dt);
    } else {
        // 3. Pas d'input : on applique la friction classique pour s'arrêter
        qreal frictionFactor = 1.0 - (m_linearDamping * dt * 60.0);
        if (frictionFactor < 0) frictionFactor = 0;
        m_velocity *= frictionFactor;
    }

    // 4. On traite les autres forces accumulées (ex: boosts, chocs extérieurs)
    QVector2D externalAccel = m_forceAccumulator * m_invMass;
    m_velocity += externalAccel * dt;

    // 5. Freinage progressif si on dépasse maxSpeed (ex: fin de sprint)
    if (m_velocity.length() > m_maxSpeed + 0.01) {
        qreal decelerationFactor = 1.0 - (m_linearDamping * dt * 60.0);
        if (decelerationFactor < 0) decelerationFactor = 0;
        m_velocity *= decelerationFactor;
        
        // On s'assure de ne pas descendre trop bas d'un coup
        if (m_velocity.length() < m_maxSpeed) {
            m_velocity = m_velocity.normalized() * m_maxSpeed;
        }
    }

    // 6. Mise à jour de la position (P = P + V*dt)
    m_position += m_velocity * dt;

    // On ne notifie les changements qu'une fois le calcul fini
    emit positionChanged();
    emit velocityChanged();
    // qDebug() << m_velocity.length() <<  "/" << m_maxSpeed;
    
    // On nettoie pour la frame suivante
    m_forceAccumulator = QVector2D(0,0);
}


void PattounX_body::setCollidingState(bool colliding, const QVector2D& normal)
{
    bool groundedChanged = (m_isColliding != colliding);
    bool normalChanged = (m_lastCollisionNormal != normal);
    
    m_isColliding = colliding;
    m_lastCollisionNormal = normal;
    
    if (groundedChanged) emit isCollidingChanged();
    if (normalChanged) emit lastCollisionNormalChanged();
}


QVector2D PattounX_body::inputVector() const
{
    return m_inputVector;
}

void PattounX_body::setInputVector(const QVector2D &newInputVector)
{
    if (m_inputVector == newInputVector)
        return;
    m_inputVector = newInputVector;
    emit inputVectorChanged();
}

qreal PattounX_body::invMass() const
{
    return m_invMass;
}

qreal PattounX_body::restitution() const
{
    return m_restitution;
}

qreal PattounX_body::staticFriction() const
{
    return m_staticFriction;
}

qreal PattounX_body::dynamicFriction() const
{
    return m_dynamicFriction;
}
