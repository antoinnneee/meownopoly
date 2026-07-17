#include "ZoneParameter.h"
#include <QJsonDocument>

// bool ZoneParameter::operator==(const ZoneParameter &other) const {
//     return m_polygonPoints         == other.m_polygonPoints
//            && m_zoneColor             == other.m_zoneColor
//            && m_zoneName              == other.m_zoneName
//            && m_velocityDirection     == other.m_velocityDirection
//            && m_velocityStrength      == other.m_velocityStrength
//            && m_frictionStrength      == other.m_frictionStrength
//            && m_exclusion             == other.m_exclusion
//            && m_speedMultiplier       == other.m_speedMultiplier
//            && m_accelerationMultiplier == other.m_accelerationMultiplier;
// }

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
    m_velocityStrength = json.value("velocityStrength").toDouble(0);
    m_frictionStrength = json.value("frictionStrength").toDouble(0.5);
    m_exclusion = json.value("exclusion").toBool(true);
    m_speedMultiplier = json.value("speedMultiplier").toDouble(1);
    m_accelerationMultiplier = json.value("accelerationMultiplier").toDouble(1);
    m_screenEffectId = json.value("screenEffectId").toString("");
    m_triggerMode = qBound(0, json.value("triggerMode").toInt(0), 1);
    m_triggerOnce = json.value("triggerOnce").toBool(false);
    m_rewardCurrency = qMax(0, json.value("rewardCurrency").toInt(0));
    m_rewardItemName = json.value("rewardItemName").toString("");
    m_rewardItemQuantity = qMax(1, json.value("rewardItemQuantity").toInt(1));
}

ZoneParameter::ZoneParameter(const ZoneParameter &other, QObject *parent)
    : QObject(parent)
    , m_polygonPoints(other.m_polygonPoints)
    , m_zoneColor(other.m_zoneColor)
    , m_zoneName(other.m_zoneName)
    , m_velocityDirection(other.m_velocityDirection)
    , m_velocityStrength(other.m_velocityStrength)
    , m_frictionStrength(other.m_frictionStrength)
    , m_exclusion(other.m_exclusion)
    , m_speedMultiplier(other.m_speedMultiplier)
    , m_accelerationMultiplier(other.m_accelerationMultiplier)
    , m_screenEffectId(other.m_screenEffectId)
    , m_triggerMode(other.m_triggerMode)
    , m_triggerOnce(other.m_triggerOnce)
    , m_rewardCurrency(other.m_rewardCurrency)
    , m_rewardItemName(other.m_rewardItemName)
    , m_rewardItemQuantity(other.m_rewardItemQuantity)
{
}

void ZoneParameter::applyJson(const QJsonObject &json)
{
    QVariantList newPoints;
    if (json.contains("polygonPoints")) {
        QJsonArray pointsArray = json["polygonPoints"].toArray();
        for (const QJsonValue &val : pointsArray) {
            QJsonObject pointObj = val.toObject();
            QVariantMap point;
            point["x"] = pointObj["x"].toDouble();
            point["y"] = pointObj["y"].toDouble();
            newPoints.append(point);
        }
    }
    setPolygonPoints(newPoints);
    setZoneColor(json.value("zoneColor").toString("#FF5722"));
    setZoneName(json.value("zoneName").toString(""));
    QJsonObject velDir = json.value("velocityDirection").toObject();
    setVelocityDirection(QVector2D(velDir.value("x").toDouble(), velDir.value("y").toDouble()));
    setVelocityStrength(json.value("velocityStrength").toDouble(0));
    setFrictionStrength(json.value("frictionStrength").toDouble(0.5));
    setExclusion(json.value("exclusion").toBool(true));
    setSpeedMultiplier(json.value("speedMultiplier").toDouble(1));
    setAccelerationMultiplier(json.value("accelerationMultiplier").toDouble(1));
    setScreenEffectId(json.value("screenEffectId").toString(""));
    setTriggerMode(json.value("triggerMode").toInt(0));
    setTriggerOnce(json.value("triggerOnce").toBool(false));
    setRewardCurrency(json.value("rewardCurrency").toInt(0));
    setRewardItemName(json.value("rewardItemName").toString(""));
    setRewardItemQuantity(json.value("rewardItemQuantity").toInt(1));
}

QJsonObject ZoneParameter::toJsonObject() const
{
    QJsonArray pointsArray;
    for (const QVariant &v : m_polygonPoints) {
        const QVariantMap point = v.toMap();
        pointsArray.append(QJsonObject{
            { "x", point["x"].toDouble() },
            { "y", point["y"].toDouble() },
        });
    }

    QJsonObject obj;
    obj["polygonPoints"] = pointsArray;
    obj["zoneColor"] = m_zoneColor;
    obj["zoneName"] = m_zoneName;
    obj["velocityDirection"] = QJsonObject{
        { "x", static_cast<double>(m_velocityDirection.x()) },
        { "y", static_cast<double>(m_velocityDirection.y()) },
    };
    obj["velocityStrength"] = m_velocityStrength;
    obj["frictionStrength"] = m_frictionStrength;
    obj["exclusion"] = m_exclusion;
    obj["speedMultiplier"] = m_speedMultiplier;
    obj["accelerationMultiplier"] = m_accelerationMultiplier;
    obj["screenEffectId"] = m_screenEffectId;
    obj["triggerMode"] = m_triggerMode;
    obj["triggerOnce"] = m_triggerOnce;
    obj["rewardCurrency"] = m_rewardCurrency;
    obj["rewardItemName"] = m_rewardItemName;
    obj["rewardItemQuantity"] = m_rewardItemQuantity;
    return obj;
}

QString ZoneParameter::toJSON()
{
    return QString::fromUtf8(
        QJsonDocument(toJsonObject()).toJson(QJsonDocument::Indented));
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

qreal ZoneParameter::velocityStrength() const
{
    return m_velocityStrength;
}

void ZoneParameter::setVelocityStrength(qreal newVelocityStrength)
{
    if (qFuzzyCompare(m_velocityStrength, newVelocityStrength))
        return;
    m_velocityStrength = newVelocityStrength;
    emit velocityStrengthChanged();
}

// frictionDirection removed

qreal ZoneParameter::frictionStrength() const
{
    return m_frictionStrength;
}

void ZoneParameter::setFrictionStrength(qreal newFrictionStrength)
{
    if (qFuzzyCompare(m_frictionStrength, newFrictionStrength))
        return;
    m_frictionStrength = newFrictionStrength;
    emit frictionStrengthChanged();
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

qreal ZoneParameter::accelerationMultiplier() const
{
    return m_accelerationMultiplier;
}

void ZoneParameter::setAccelerationMultiplier(qreal newAccelerationMultiplier)
{
    if (qFuzzyCompare(m_accelerationMultiplier, newAccelerationMultiplier))
        return;
    m_accelerationMultiplier = newAccelerationMultiplier;
    emit accelerationMultiplierChanged();
}

void ZoneParameter::setTriggerMode(int newTriggerMode)
{
    newTriggerMode = qBound(0, newTriggerMode, 1);
    if (m_triggerMode == newTriggerMode)
        return;
    m_triggerMode = newTriggerMode;
    emit triggerModeChanged();
}

void ZoneParameter::setTriggerOnce(bool newTriggerOnce)
{
    if (m_triggerOnce == newTriggerOnce)
        return;
    m_triggerOnce = newTriggerOnce;
    emit triggerOnceChanged();
}

void ZoneParameter::setRewardCurrency(int newRewardCurrency)
{
    newRewardCurrency = qMax(0, newRewardCurrency);
    if (m_rewardCurrency == newRewardCurrency)
        return;
    m_rewardCurrency = newRewardCurrency;
    emit rewardCurrencyChanged();
}

void ZoneParameter::setRewardItemName(const QString &newRewardItemName)
{
    if (m_rewardItemName == newRewardItemName)
        return;
    m_rewardItemName = newRewardItemName;
    emit rewardItemNameChanged();
}

void ZoneParameter::setRewardItemQuantity(int newRewardItemQuantity)
{
    newRewardItemQuantity = qMax(1, newRewardItemQuantity);
    if (m_rewardItemQuantity == newRewardItemQuantity)
        return;
    m_rewardItemQuantity = newRewardItemQuantity;
    emit rewardItemQuantityChanged();
}

QString ZoneParameter::screenEffectId() const
{
    return m_screenEffectId;
}

void ZoneParameter::setScreenEffectId(const QString &newScreenEffectId)
{
    if (m_screenEffectId == newScreenEffectId)
        return;
    m_screenEffectId = newScreenEffectId;
    emit screenEffectIdChanged();
}
