#include "ZoneParameter.h"
#include <QJsonDocument>

ZoneParameter::ZoneParameter(QObject *parent)
    : QObject(parent)
    , m_zoneColor("#FF5722")  // Orange par défaut
    , m_zoneName("")
{
}

ZoneParameter::ZoneParameter(const QJsonObject &json, QObject *parent)
    : QObject(parent)
{
    if (json.contains("polygonPoints")) {
        QJsonArray pointsArray = json["polygonPoints"].toArray();
        for (const QJsonValue &val : pointsArray) {
            QJsonObject pointObj = val.toObject();
            QVariantMap point;
            point["x"] = pointObj["x"].toDouble();
            point["y"] = pointObj["y"].toDouble();
            m_polygonPoints.append(point);
        }
    }
    
    m_zoneColor = json.value("zoneColor").toString("#FF5722");
    m_zoneName = json.value("zoneName").toString("");
    m_velocityDirection = QVector2D(json.value("velocityDirection").toObject().value("x").toDouble(), json.value("velocityDirection").toObject().value("y").toDouble());
    m_velocityStrenght = json.value("velocityStrenght").toDouble(0);
    m_frictionDirection = QVector2D(json.value("frictionDirection").toObject().value("x").toDouble(), json.value("frictionDirection").toObject().value("y").toDouble());
    m_frictionStrenght = json.value("frictionStrenght").toDouble(0);
    m_exclusion = json.value("exclusion").toBool(true);
    m_speedMultiplier = json.value("speedMultiplier").toDouble(0);
}

QString ZoneParameter::toJSON()
{
    QString json;
    json += "{\n";
    json += "    \"polygonPoints\": [";
    
    for (int i = 0; i < m_polygonPoints.size(); ++i) {
        QVariantMap point = m_polygonPoints[i].toMap();
        json += QString("{ \"x\": %1, \"y\": %2 }")
                    .arg(point["x"].toDouble())
                    .arg(point["y"].toDouble());
        if (i < m_polygonPoints.size() - 1) {
            json += ", ";
        }
    }

    QString exclusionStr = (m_exclusion ? "true" : "false");
    
    json += "],\n";
    json += "    \"zoneColor\": \"" + m_zoneColor + "\",\n";
    json += "    \"zoneName\": \"" + m_zoneName + "\",\n";
    json += "    \"velocityDirection\": { \"x\": " + QString::number(m_velocityDirection.x()) + ", \"y\": " + QString::number(m_velocityDirection.y()) + " },\n";
    json += "    \"velocityStrenght\": " + QString::number(m_velocityStrenght) + ",\n";
    json += "    \"frictionDirection\": { \"x\": " + QString::number(m_frictionDirection.x()) + ", \"y\": " + QString::number(m_frictionDirection.y()) + " },\n";
    json += "    \"frictionStrenght\": " + QString::number(m_frictionStrenght) + ",\n";
    json += "    \"exclusion\": " + exclusionStr + ",\n";
    json += "    \"speedMultiplier\": " + QString::number(m_speedMultiplier) + "\n";
    json += "}";
    
    return json;
}

QVariantList ZoneParameter::polygonPoints() const
{
    return m_polygonPoints;
}

void ZoneParameter::setPolygonPoints(const QVariantList &points)
{
    if (m_polygonPoints != points) {
        m_polygonPoints = points;
        emit polygonPointsChanged();
    }
}

void ZoneParameter::addPoint(qreal x, qreal y)
{
    QVariantMap point;
    point["x"] = x;
    point["y"] = y;
    m_polygonPoints.append(point);
    emit polygonPointsChanged();
}

void ZoneParameter::removeLastPoint()
{
    if (!m_polygonPoints.isEmpty()) {
        m_polygonPoints.removeLast();
        emit polygonPointsChanged();
    }
}

void ZoneParameter::clearPoints()
{
    if (!m_polygonPoints.isEmpty()) {
        m_polygonPoints.clear();
        emit polygonPointsChanged();
    }
}

int ZoneParameter::pointCount() const
{
    return m_polygonPoints.size();
}

QString ZoneParameter::zoneColor() const
{
    return m_zoneColor;
}

void ZoneParameter::setZoneColor(const QString &color)
{
    if (m_zoneColor != color) {
        m_zoneColor = color;
        emit zoneColorChanged();
    }
}

QString ZoneParameter::zoneName() const
{
    return m_zoneName;
}

void ZoneParameter::setZoneName(const QString &name)
{
    if (m_zoneName != name) {
        m_zoneName = name;
        emit zoneNameChanged();
    }
}


QVector2D ZoneParameter::velocityDirection() const
{
    return m_velocityDirection;
}

void ZoneParameter::setVelocityDirection(const QVector2D &newVelocityDirection)
{
    if (m_velocityDirection == newVelocityDirection)
        return;
    m_velocityDirection = newVelocityDirection;
    emit velocityDirectionChanged();
}

qreal ZoneParameter::velocityStrenght() const
{
    return m_velocityStrenght;
}

void ZoneParameter::setVelocityStrenght(qreal newVelocityStrenght)
{
    if (qFuzzyCompare(m_velocityStrenght, newVelocityStrenght))
        return;
    m_velocityStrenght = newVelocityStrenght;
    emit velocityStrenghtChanged();
}

QVector2D ZoneParameter::frictionDirection() const
{
    return m_frictionDirection;
}

void ZoneParameter::setFrictionDirection(const QVector2D &newFrictionDirection)
{
    if (m_frictionDirection == newFrictionDirection)
        return;
    m_frictionDirection = newFrictionDirection;
    emit frictionDirectionChanged();
}

qreal ZoneParameter::frictionStrenght() const
{
    return m_frictionStrenght;
}

void ZoneParameter::setFrictionStrenght(qreal newFrictionStrenght)
{
    if (qFuzzyCompare(m_frictionStrenght, newFrictionStrenght))
        return;
    m_frictionStrenght = newFrictionStrenght;
    emit frictionStrenghtChanged();
}

bool ZoneParameter::exclusion() const
{
    return m_exclusion;
}

void ZoneParameter::setExclusion(bool newExclusion)
{
    if (m_exclusion == newExclusion)
        return;
    m_exclusion = newExclusion;
    emit exclusionChanged();
}

qreal ZoneParameter::speedMultiplier() const
{
    return m_speedMultiplier;
}

void ZoneParameter::setSpeedMultiplier(qreal newSpeedMultiplier)
{
    if (qFuzzyCompare(m_speedMultiplier, newSpeedMultiplier))
        return;
    m_speedMultiplier = newSpeedMultiplier;
    emit speedMultiplierChanged();
}
