#include "pattounx_zone.h"

#include "game/item_snapable/ZoneParameter.h"

PattounX_zone::PattounX_zone(const QString& id, QObject* parent)
    : ZoneParameter(parent)
    , m_zoneId(id)
{

}

PattounX_zone::PattounX_zone(const QString& id, ZoneParameter &zoneParameter, QObject* parent)
    : ZoneParameter(zoneParameter, parent)
    , m_zoneId(id)
{
    m_polygon = Polygon2D::fromVariantList(zoneParameter.polygonPoints());
}


bool PattounX_zone::containsPoint(const QVector2D& point) const
{
    if (!m_isActive || !m_polygon.isValid()) {
        return false;
    }
    return Collision2D::pointInPolygon(point, m_polygon);
}


CollisionResult PattounX_zone::checkCollision(const QVector2D& center, qreal radius) const
{
    CollisionResult result;

    if (!m_isActive || !m_polygon.isValid()) {
        return result;
    }

    // Seules les zones d'exclusion génèrent des collisions physiques
    if (exclusion() == true) {
        result = Collision2D::checkCirclePolygon(center, radius, m_polygon);
        if (result.colliding) {
            result.zone = const_cast<PattounX_zone*>(this);
        }
    }

    return result;
}

CollisionResult PattounX_zone::checkCollisionSweep(const QVector2D& startPos, const QVector2D& endPos, qreal radius) const
{
    CollisionResult result;

    if (!m_isActive || !m_polygon.isValid()) {
        return result;
    }

    // Seules les zones d'exclusion génèrent des collisions physiques
    if (exclusion() == true) {
        result = Collision2D::checkCirclePolygonSweep(startPos, endPos, radius, m_polygon);
        if (result.colliding) {
            result.zone = const_cast<PattounX_zone*>(this);
        }
    }

    return result;
}

QVector<CollisionResult> PattounX_zone::checkCollisionAll(const QVector2D& center, qreal radius) const
{
    QVector<CollisionResult> results;
    if (!m_isActive || !m_polygon.isValid() || !exclusion()) return results;
    
    results = Collision2D::checkCirclePolygonAll(center, radius, m_polygon);
    for (auto& res : results) res.zone = const_cast<PattounX_zone*>(this);
    return results;
}

QVector<CollisionResult> PattounX_zone::checkCollisionSweepAll(const QVector2D& startPos, const QVector2D& endPos, qreal radius) const
{
    QVector<CollisionResult> results;
    if (!m_isActive || !m_polygon.isValid() || !exclusion()) return results;
    
    results = Collision2D::checkCirclePolygonSweepAll(startPos, endPos, radius, m_polygon);
    for (auto& res : results) res.zone = const_cast<PattounX_zone*>(this);
    return results;
}

