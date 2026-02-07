#include "pattounx_zone.h"
#include <QUuid>

#include "game/item_snapable/ZoneParameter.h"
#include "game/item_snapable/Displayparameter.h"

PattounX_zone::PattounX_zone(ItemSnapable* snapable, QObject* parent)
    : QObject(parent)
    , m_snapable(snapable)
{
    if (m_snapable) {
        if (m_snapable->zoneParameter()) {
            connect(m_snapable->zoneParameter(), &ZoneParameter::polygonPointsChanged, this, &PattounX_zone::updatePolygon);
            updatePolygon();
        }
        if (m_snapable->displayParameter()) {
            connect(m_snapable->displayParameter(), &DisplayParameter::gridRelativePositionXChanged,
                    this, &PattounX_zone::updatePolygon);
            connect(m_snapable->displayParameter(), &DisplayParameter::gridRelativePositionYChanged,
                    this, &PattounX_zone::updatePolygon);
        }
    }
}

QString PattounX_zone::zoneId() const
{
    if (m_snapable) {
        return m_snapable->uniqueId().toString();
    }
    return QString();
}

bool PattounX_zone::exclusion() const
{
    if (m_snapable && m_snapable->zoneParameter()) {
        return m_snapable->zoneParameter()->exclusion();
    }
    return false;
}

ZoneParameter* PattounX_zone::zoneParameter() const
{
    if (m_snapable) {
        return m_snapable->zoneParameter();
    }
    return nullptr;
}

void PattounX_zone::updatePolygon()
{
    if (m_snapable && m_snapable->zoneParameter()) {
        QVariantList relativePoints = m_snapable->zoneParameter()->polygonPoints();
        DisplayParameter* dp = m_snapable->displayParameter();
        qreal offsetX = dp ? dp->gridRelativePositionX() : 0;
        qreal offsetY = dp ? dp->gridRelativePositionY() : 0;

        QVariantList absolutePoints;
        for (const QVariant& var : relativePoints) {
            QVariantMap pt = var.toMap();
            QVariantMap absPt;
            absPt["x"] = pt["x"].toDouble() + offsetX;
            absPt["y"] = pt["y"].toDouble() + offsetY;
            absolutePoints.append(absPt);
        }
        m_polygon = Polygon2D::fromVariantList(absolutePoints);
    }
}

const ZoneParameter& PattounX_zone::getZoneParameters() const
{
    static ZoneParameter empty;
    if (m_snapable && m_snapable->zoneParameter()) {
        return *m_snapable->zoneParameter();
    }
    return empty;
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

