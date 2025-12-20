#include "physics2d_zone.h"

PhysicsZone2D::PhysicsZone2D(QObject* parent)
    : QObject(parent)
    , m_zoneId("")
    , m_zoneType(Exclusion)
    , m_effectStrength(1.0)
    , m_effectDirection(0, 0)
    , m_isActive(true)
{
}

PhysicsZone2D::PhysicsZone2D(const QString& id, ZoneType type, QObject* parent)
    : QObject(parent)
    , m_zoneId(id)
    , m_zoneType(type)
    , m_effectStrength(1.0)
    , m_effectDirection(0, 0)
    , m_isActive(true)
{
    // Valeurs par défaut selon le type
    switch (type) {
        case SpeedBoost:
            m_effectStrength = 2.0;  // Vitesse x2
            m_zoneColor = "#4CAF50"; // Vert
            break;
        case SpeedSlow:
            m_effectStrength = 0.5;  // Vitesse /2
            m_zoneColor = "#9C27B0"; // Violet
            break;
        case IceZone:
            m_effectStrength = 0.1;  // Friction très basse
            m_zoneColor = "#00BCD4"; // Cyan
            break;
        case ConveyorBelt:
            m_effectStrength = 5.0;  // Force du tapis
            m_effectDirection = QVector2D(1, 0); // Vers la droite par défaut
            m_zoneColor = "#795548"; // Marron
            break;
        case JumpPad:
            m_effectStrength = 15.0; // Force d'impulsion
            m_zoneColor = "#FFEB3B"; // Jaune
            break;
        case DamageZone:
            m_effectStrength = 10.0; // Dégâts par seconde
            m_zoneColor = "#F44336"; // Rouge
            break;
        case HealZone:
            m_effectStrength = 5.0;  // Soin par seconde
            m_zoneColor = "#E91E63"; // Rose
            break;
        default:
            m_zoneColor = "#FF5722"; // Orange (exclusion)
            break;
    }
}

void PhysicsZone2D::setZoneType(ZoneType type)
{
    if (m_zoneType != type) {
        m_zoneType = type;
        emit zoneTypeChanged();
    }
}

void PhysicsZone2D::setPolygon(const QVariantList& points)
{
    if (m_polygonVariant != points) {
        m_polygonVariant = points;
        m_polygon = Polygon2D::fromVariantList(points);
        emit polygonChanged();
    }
}

void PhysicsZone2D::setEffectStrength(qreal strength)
{
    if (!qFuzzyCompare(m_effectStrength, strength)) {
        m_effectStrength = strength;
        emit effectStrengthChanged();
    }
}

void PhysicsZone2D::setEffectDirection(const QVector2D& direction)
{
    if (m_effectDirection != direction) {
        m_effectDirection = direction;
        emit effectDirectionChanged();
    }
}

void PhysicsZone2D::setIsActive(bool active)
{
    if (m_isActive != active) {
        m_isActive = active;
        emit isActiveChanged();
    }
}

void PhysicsZone2D::setZoneName(const QString& name)
{
    if (m_zoneName != name) {
        m_zoneName = name;
        emit zoneNameChanged();
    }
}

void PhysicsZone2D::setZoneColor(const QString& color)
{
    if (m_zoneColor != color) {
        m_zoneColor = color;
        emit zoneColorChanged();
    }
}

bool PhysicsZone2D::containsPoint(const QVector2D& point) const
{
    if (!m_isActive || !m_polygon.isValid()) {
        return false;
    }
    return Collision2D::pointInPolygon(point, m_polygon);
}

qreal PhysicsZone2D::getEffectMultiplier() const
{
    if (!m_isActive) return 1.0;
    
    switch (m_zoneType) {
        case SpeedBoost:
        case SpeedSlow:
            return m_effectStrength;
        default:
            return 1.0;
    }
}

qreal PhysicsZone2D::getFrictionModifier() const
{
    if (!m_isActive) return 1.0;
    
    switch (m_zoneType) {
        case IceZone:
            return m_effectStrength; // Valeur basse = glissant
        default:
            return 1.0;
    }
}

CollisionResult PhysicsZone2D::checkCollision(const QVector2D& center, qreal radius) const
{
    CollisionResult result;
    
    if (!m_isActive || !m_polygon.isValid()) {
        return result;
    }
    
    // Seules les zones d'exclusion génèrent des collisions physiques
    if (m_zoneType == Exclusion) {
        result = Collision2D::checkCirclePolygon(center, radius, m_polygon);
        if (result.colliding) {
            result.zone = const_cast<PhysicsZone2D*>(this);
        }
    }
    
    return result;
}

