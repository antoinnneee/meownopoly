#ifndef PHYSICS2D_BODY_H
#define PHYSICS2D_BODY_H

#include <QObject>
#include <QVector2D>
#include <QVector3D>
#include <QString>
#include <QHash>

// Forward declarations
class PhysicsEngine2D;
class PhysicsZone2D;

/**
 * @brief Corps physique 2D
 * 
 * Représente une entité avec position, vitesse et paramètres
 * de collision dans le système de coordonnées de grille 2D.
 */
class PhysicsBody2D : public QObject
{
    Q_OBJECT
    
    Q_PROPERTY(QString bodyId READ bodyId CONSTANT)
    Q_PROPERTY(QVector2D position READ position WRITE setPosition NOTIFY positionChanged)
    Q_PROPERTY(QVector2D velocity READ velocity WRITE setVelocity NOTIFY velocityChanged)
    Q_PROPERTY(qreal collisionRadius READ collisionRadius WRITE setCollisionRadius NOTIFY collisionRadiusChanged)
    Q_PROPERTY(qreal bounceFactor READ bounceFactor WRITE setBounceFactor NOTIFY bounceFactorChanged)
    Q_PROPERTY(qreal slideFactor READ slideFactor WRITE setSlideFactor NOTIFY slideFactorChanged)
    Q_PROPERTY(qreal acceleration READ acceleration WRITE setAcceleration NOTIFY accelerationChanged)
    Q_PROPERTY(qreal maxSpeed READ maxSpeed WRITE setMaxSpeed NOTIFY maxSpeedChanged)
    Q_PROPERTY(qreal mass READ mass WRITE setMass NOTIFY massChanged)
    Q_PROPERTY(bool isStatic READ isStatic WRITE setIsStatic NOTIFY isStaticChanged)
    Q_PROPERTY(bool collisionEnabled READ collisionEnabled WRITE setCollisionEnabled NOTIFY collisionEnabledChanged)
    
    // État de lecture seule
    Q_PROPERTY(bool isColliding READ isColliding NOTIFY isCollidingChanged)
    Q_PROPERTY(QVector2D lastCollisionNormal READ lastCollisionNormal NOTIFY lastCollisionNormalChanged)

public:
    explicit PhysicsBody2D(QObject* parent = nullptr);
    explicit PhysicsBody2D(const QString& id, QObject* parent = nullptr);
    
    // --- Getters ---
    QString bodyId() const { return m_bodyId; }
    QVector2D position() const { return m_position; }
    QVector2D velocity() const { return m_velocity; }
    qreal collisionRadius() const { return m_collisionRadius; }
    qreal bounceFactor() const { return m_bounceFactor; }
    qreal slideFactor() const { return m_slideFactor; }
    qreal acceleration() const { return m_acceleration; }
    qreal maxSpeed() const { return m_maxSpeed; }
    qreal mass() const { return m_mass; }
    bool isStatic() const { return m_isStatic; }
    bool collisionEnabled() const { return m_collisionEnabled; }
    bool isColliding() const { return m_isColliding; }
    QVector2D lastCollisionNormal() const { return m_lastCollisionNormal; }
    
    // --- Setters ---
    void setPosition(const QVector2D& pos);
    void setVelocity(const QVector2D& vel);
    void setCollisionRadius(qreal radius);
    void setBounceFactor(qreal factor);
    void setSlideFactor(qreal factor);
    void setAcceleration(qreal accel);
    void setMaxSpeed(qreal speed);
    void setMass(qreal mass);
    void setIsStatic(bool isStatic);
    void setCollisionEnabled(bool enabled);
    
    // --- API Publique (Q_INVOKABLE pour QML) ---
    
    /**
     * @brief Applique une force d'entrée et met à jour la physique
     * @param inputForce Vecteur de force d'entrée (direction normalisée)
     * @param dt Delta time en secondes
     */
    Q_INVOKABLE void applyForce(const QVector2D& inputForce, qreal dt);
    
    /**
     * @brief Applique une impulsion instantanée
     * @param impulse Vecteur d'impulsion
     */
    Q_INVOKABLE void applyImpulse(const QVector2D& impulse);

    /**
     * @brief Arrête le mouvement
     */
    Q_INVOKABLE void stop();
    
    /**
     * @brief Remet à zéro la vitesse et l'état
     */
    Q_INVOKABLE void reset();
    
    // --- Usage interne par PhysicsEngine2D ---
    
    /**
     * @brief Applique le modificateur de vitesse (depuis les zones)
     */
    void applySpeedModifier(qreal modifier);
    
    /**
     * @brief Applique le modificateur de friction (depuis les zones)
     */
    void applyFrictionModifier(qreal modifier);
    
    /**
     * @brief Applique une force directionnelle (tapis roulant)
     */
    void applyDirectionalForce(const QVector2D& force, qreal dt);

    /**
     * @brief Applique une force continue depuis une zone
     * @param force Vecteur de force à appliquer
     * @param dt Delta time en secondes
     * @param zoneId ID de la zone appliquant la force (pour suivi)
     */
    void applyZoneForce(const QVector2D& force, qreal dt, const QString& zoneId = QString());

    /**
     * @brief Applique une force de friction directionnelle
     * @param frictionDirection Direction de la friction
     * @param frictionStrength Intensité de la friction (0-1)
     * @param dt Delta time en secondes
     */
    void applyDirectionalFriction(const QVector2D& frictionDirection, qreal frictionStrength, qreal dt);

    /**
     * @brief Applique un multiplicateur de vitesse depuis une zone
     * @param multiplier Multiplicateur de vitesse (> 0)
     * @param zoneId ID de la zone appliquant le modificateur
     */
    void applyZoneSpeedMultiplier(qreal multiplier, const QString& zoneId = QString());
    
    /**
     * @brief Met à jour l'état de collision
     */
    void setCollidingState(bool colliding, const QVector2D& normal);
    
    /**
     * @brief Référence vers le moteur physique parent
     */
    void setEngine(PhysicsEngine2D* engine) { m_engine = engine; }
    PhysicsEngine2D* engine() const { return m_engine; }

signals:
    void positionChanged();
    void velocityChanged();
    void collisionRadiusChanged();
    void bounceFactorChanged();
    void slideFactorChanged();
    void accelerationChanged();
    void maxSpeedChanged();
    void massChanged();
    void isStaticChanged();
    void collisionEnabledChanged();
    void isCollidingChanged();
    void lastCollisionNormalChanged();
    
    // Événements
    void collisionOccurred(PhysicsZone2D* zone);
    void enteredZone(PhysicsZone2D* zone);
    void exitedZone(PhysicsZone2D* zone);

private:
    QString m_bodyId;
    QVector2D m_position;
    QVector2D m_velocity;
    qreal m_collisionRadius = 0.2;
    qreal m_bounceFactor = 0.1;
    qreal m_slideFactor = 1.0;
    qreal m_acceleration = 30.0;
    qreal m_maxSpeed = 36.0;  // moveSpeed * sprintMultiplier
    qreal m_mass = 1.0;
    bool m_isStatic = false;
    bool m_collisionEnabled = true;
    
    // État
    bool m_isColliding = false;
    QVector2D m_lastCollisionNormal;
    
    // Modificateurs temporaires (réinitialisés chaque frame)
    qreal m_currentSpeedModifier = 1.0;
    qreal m_currentFrictionModifier = 1.0;

    // Forces continues appliquées par les zones
    QHash<QString, QVector2D> m_zoneForces;  // force par zone
    QVector2D m_totalZoneForce;              // somme des forces de zones

    // Modificateurs de vitesse par zone
    QHash<QString, qreal> m_zoneSpeedMultipliers;
    
    // Référence au moteur
    PhysicsEngine2D* m_engine = nullptr;
};

#endif // PHYSICS2D_BODY_H

