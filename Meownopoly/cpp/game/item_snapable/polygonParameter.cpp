#include "polygonParameter.h"
#include <QJsonDocument>

PolygonParameter::PolygonParameter(QObject *parent)
    : QObject(parent)
    , m_zoneColor("#FF5722")  // Orange par défaut
    , m_zoneName("")
{
}

PolygonParameter::PolygonParameter(const QJsonObject &json, QObject *parent)
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
}

QString PolygonParameter::toJSON()
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
    
    json += "],\n";
    json += "    \"zoneColor\": \"" + m_zoneColor + "\",\n";
    json += "    \"zoneName\": \"" + m_zoneName + "\"\n";
    json += "}";
    
    return json;
}

QVariantList PolygonParameter::polygonPoints() const
{
    return m_polygonPoints;
}

void PolygonParameter::setPolygonPoints(const QVariantList &points)
{
    if (m_polygonPoints != points) {
        m_polygonPoints = points;
        emit polygonPointsChanged();
    }
}

void PolygonParameter::addPoint(qreal x, qreal y)
{
    QVariantMap point;
    point["x"] = x;
    point["y"] = y;
    m_polygonPoints.append(point);
    emit polygonPointsChanged();
}

void PolygonParameter::removeLastPoint()
{
    if (!m_polygonPoints.isEmpty()) {
        m_polygonPoints.removeLast();
        emit polygonPointsChanged();
    }
}

void PolygonParameter::clearPoints()
{
    if (!m_polygonPoints.isEmpty()) {
        m_polygonPoints.clear();
        emit polygonPointsChanged();
    }
}

int PolygonParameter::pointCount() const
{
    return m_polygonPoints.size();
}

QString PolygonParameter::zoneColor() const
{
    return m_zoneColor;
}

void PolygonParameter::setZoneColor(const QString &color)
{
    if (m_zoneColor != color) {
        m_zoneColor = color;
        emit zoneColorChanged();
    }
}

QString PolygonParameter::zoneName() const
{
    return m_zoneName;
}

void PolygonParameter::setZoneName(const QString &name)
{
    if (m_zoneName != name) {
        m_zoneName = name;
        emit zoneNameChanged();
    }
}

