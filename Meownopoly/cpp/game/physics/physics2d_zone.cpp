#include "physics2d_zone.h"

#include "game/item_snapable/ZoneParameter.h"

PhysicsZone2D::PhysicsZone2D(const QString& id, QObject* parent)
    : ZoneParameter(parent)
    , m_zoneId(id)
{

}

PhysicsZone2D::PhysicsZone2D(const QString& id, ZoneParameter &zoneParameter, QObject* parent)
    : ZoneParameter(zoneParameter, parent)
    , m_zoneId(id)
{
    m_polygon = Polygon2D::fromVariantList(zoneParameter.polygonPoints());
}


bool PhysicsZone2D::containsPoint(const QVector2D& point) const
{
    if (!m_isActive || !m_polygon.isValid()) {
        return false;
    }
    return Collision2D::pointInPolygon(point, m_polygon);
}


CollisionResult PhysicsZone2D::checkCollision(const QVector2D& center, qreal radius) const
{
    CollisionResult result;

    if (!m_isActive || !m_polygon.isValid()) {
        return result;
    }

    // Seules les zones d'exclusion génèrent des collisions physiques
    if (exclusion() == true) {
        result = Collision2D::checkCirclePolygon(center, radius, m_polygon);
        if (result.colliding) {
            result.zone = const_cast<PhysicsZone2D*>(this);
        }
    }

    return result;
}

CollisionResult PhysicsZone2D::checkCollisionSweep(const QVector2D& startPos, const QVector2D& endPos, qreal radius) const
{
    CollisionResult result;

    if (!m_isActive || !m_polygon.isValid()) {
        return result;
    }

    // Seules les zones d'exclusion génèrent des collisions physiques
    if (exclusion() == true) {
        result = Collision2D::checkCirclePolygonSweep(startPos, endPos, radius, m_polygon);
        if (result.colliding) {
            result.zone = const_cast<PhysicsZone2D*>(this);
        }
    }

    return result;
}

