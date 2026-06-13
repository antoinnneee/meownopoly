#ifndef ZONEPARAMETER_H
#define ZONEPARAMETER_H

#include <QObject>
#include <QPointF>
#include <QVariantList>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector2D>

class ZoneParameter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString zoneColor READ zoneColor WRITE setZoneColor NOTIFY zoneColorChanged)
    Q_PROPERTY(QString zoneName READ zoneName WRITE setZoneName NOTIFY zoneNameChanged)
    Q_PROPERTY(QVariantList polygonPoints READ polygonPoints WRITE setPolygonPoints NOTIFY polygonPointsChanged)
    Q_PROPERTY(QVector2D velocityDirection READ velocityDirection WRITE setVelocityDirection NOTIFY velocityDirectionChanged FINAL)
    Q_PROPERTY(qreal velocityStrenght READ velocityStrenght WRITE setVelocityStrenght NOTIFY velocityStrenghtChanged FINAL)
    Q_PROPERTY(qreal frictionStrenght READ frictionStrenght WRITE setFrictionStrenght NOTIFY frictionStrenghtChanged FINAL)
    Q_PROPERTY(qreal speedMultiplier READ speedMultiplier WRITE setSpeedMultiplier NOTIFY speedMultiplierChanged FINAL)
    Q_PROPERTY(bool exclusion READ exclusion WRITE setExclusion NOTIFY exclusionChanged FINAL)
    Q_PROPERTY(qreal accelerationMultiplier READ accelerationMultiplier WRITE setAccelerationMultiplier NOTIFY accelerationMultiplierChanged FINAL)
    // Référence (id) vers un ScreenEffect de la bibliothèque de la carte
    // (MapInfo::screenEffects). Vide = aucun effet visuel à l'entrée de zone.
    Q_PROPERTY(QString screenEffectId READ screenEffectId WRITE setScreenEffectId NOTIFY screenEffectIdChanged FINAL)

public:

    // bool operator==(const ZoneParameter &other) const;

    bool operator==(const ZoneParameter &other) const {
        qDebug() << "Comparing ZoneParameter with zoneName:" << zoneName() << "to ZoneParameter with zoneName:" << other.zoneName();
        return m_polygonPoints         == other.m_polygonPoints
               && m_zoneColor             == other.m_zoneColor
               && m_zoneName              == other.m_zoneName
               && m_velocityDirection     == other.m_velocityDirection
               && m_velocityStrenght      == other.m_velocityStrenght
               && m_frictionStrenght      == other.m_frictionStrenght
               && m_exclusion             == other.m_exclusion
               && m_speedMultiplier       == other.m_speedMultiplier
               && m_accelerationMultiplier == other.m_accelerationMultiplier
               && m_screenEffectId        == other.m_screenEffectId;
    }

    explicit ZoneParameter(QObject *parent = nullptr);
    explicit ZoneParameter(const QJsonObject &json, QObject *parent = nullptr);
    explicit ZoneParameter(const ZoneParameter &other, QObject *parent = nullptr);
    QString toJSON();
    void applyJson(const QJsonObject &json);
    
    QVariantList polygonPoints() const;
    void setPolygonPoints(const QVariantList &points);
    
    Q_INVOKABLE void addPoint(qreal x, qreal y);
    Q_INVOKABLE void removeLastPoint();
    Q_INVOKABLE void clearPoints();
    Q_INVOKABLE int pointCount() const;
    
    QString zoneColor() const;
    void setZoneColor(const QString &color);
    
    QString zoneName() const;
    void setZoneName(const QString &name);

    QVector2D velocityDirection() const;
    void setVelocityDirection(const QVector2D &newVelocityDirection);

    qreal velocityStrenght() const;
    void setVelocityStrenght(qreal newVelocityStrenght);



    qreal frictionStrenght() const;
    void setFrictionStrenght(qreal newFrictionStrenght);

    bool exclusion() const;
    void setExclusion(bool newExclusion);

    qreal speedMultiplier() const;
    void setSpeedMultiplier(qreal newSpeedMultiplier);

    qreal accelerationMultiplier() const;
    void setAccelerationMultiplier(qreal newAccelerationMultiplier);

    QString screenEffectId() const;
    void setScreenEffectId(const QString &newScreenEffectId);



signals:
    void polygonPointsChanged();
    void zoneColorChanged();
    void zoneNameChanged();

    void velocityDirectionChanged();

    void velocityStrenghtChanged();



    void frictionStrenghtChanged();

    void exclusionChanged();

    void speedMultiplierChanged();

    void accelerationMultiplierChanged();

    void screenEffectIdChanged();

private:
    QVariantList m_polygonPoints;
    QString m_zoneColor;
    QString m_zoneName;
    QVector2D m_velocityDirection = QVector2D(0, 0);
    qreal m_velocityStrenght = 0;
    qreal m_frictionStrenght = 0;
    bool m_exclusion = true;
    qreal m_speedMultiplier = 1;
    qreal m_accelerationMultiplier = 1;
    QString m_screenEffectId;
};

#endif // ZONEPARAMETER_H

