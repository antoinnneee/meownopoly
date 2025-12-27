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
void PhysicsBody2D::applyForce(const QVector2D& inputVector, qreal inputForce) {
    applyForce(inputVector * inputForce);
}

void PhysicsBody2D::applyForce(const QVector2D& force)
{
    // On ajoute directement à l'accumulateur ou à la vitesse si intégration Euler simple
    if (m_isStatic) return;
        m_forceAccumulator += force;
}


void PhysicsBody2D::applyImpulse(const QVector2D& impulse)
{
    if (m_isStatic) return;
        m_velocity += impulse * m_invMass;
    emit velocityChanged();
}

void PhysicsBody2D::setLinearDamping(qreal damping)
{
    m_linearDamping = damping;
}

void PhysicsBody2D::stop() {
    m_velocity = QVector2D(0,0);
    m_forceAccumulator = QVector2D(0,0);
    emit velocityChanged();
}

void PhysicsBody2D::reset() {
    stop();
}
// --- Usage intern

void PhysicsBody2D::integrate(qreal dt) {
    if (m_isStatic || dt <= 0) return;

    // 1. Calcul de l'accélération (a = F / m)
    QVector2D acceleration = m_forceAccumulator * m_invMass;

    // 2. Mise à jour de la vitesse (V = V + a*dt)
    m_velocity += acceleration * dt;

    // 3. Application de la friction globale (Damping)
    // On combine la friction du monde et le damping propre au body
//    m_velocity *= std::pow(m_linearDamping * (1.0 - worldFriction), dt);
    
    
    // 3. LE SOL RALENTIT LA VITESSE (Damping)
    //m_velocity *= std::pow(1.0 - m_linearDamping, dt * 60.0); // en cas de probleme 
    qreal frictionFactor = 1.0 - (m_linearDamping * dt * 60.0);
    if (frictionFactor < 0) frictionFactor = 0; // Sécurité
    m_velocity *= frictionFactor;

    // 4. Mise à jour de la position (P = P + V*dt)
    m_position += m_velocity * dt;

    // On ne notifie les changements qu'une fois le calcul fini
    emit positionChanged();
    emit velocityChanged();
    
    // On nettoie pour la frame suivante
    m_forceAccumulator = QVector2D(0,0);
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
