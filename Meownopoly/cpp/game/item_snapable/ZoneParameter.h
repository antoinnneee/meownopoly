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
    Q_PROPERTY(QVector2D frictionDirection READ frictionDirection WRITE setFrictionDirection NOTIFY frictionDirectionChanged FINAL)
    Q_PROPERTY(qreal velocityStrenght READ velocityStrenght WRITE setVelocityStrenght NOTIFY velocityStrenghtChanged FINAL)
    Q_PROPERTY(qreal frictionStrenght READ frictionStrenght WRITE setFrictionStrenght NOTIFY frictionStrenghtChanged FINAL)
    Q_PROPERTY(qreal speedMultiplier READ speedMultiplier WRITE setSpeedMultiplier NOTIFY speedMultiplierChanged FINAL)
    Q_PROPERTY(bool exclusion READ exclusion WRITE setExclusion NOTIFY exclusionChanged FINAL)
public:
    explicit ZoneParameter(QObject *parent = nullptr);
    explicit ZoneParameter(const QJsonObject &json, QObject *parent = nullptr);
    QString toJSON();
    
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

    QVector2D frictionDirection() const;
    void setFrictionDirection(const QVector2D &newFrictionDirection);

    qreal frictionStrenght() const;
    void setFrictionStrenght(qreal newFrictionStrenght);

    bool exclusion() const;
    void setExclusion(bool newExclusion);

    qreal speedMultiplier() const;
    void setSpeedMultiplier(qreal newSpeedMultiplier);

signals:
    void polygonPointsChanged();
    void zoneColorChanged();
    void zoneNameChanged();

    void velocityDirectionChanged();

    void velocityStrenghtChanged();

    void frictionDirectionChanged();

    void frictionStrenghtChanged();

    void exclusionChanged();

    void speedMultiplierChanged();

private:
    QVariantList m_polygonPoints;
    QString m_zoneColor;
    QString m_zoneName;
    QVector2D m_velocityDirection = QVector2D(0, 0);
    qreal m_velocityStrenght = 0;
    QVector2D m_frictionDirection = QVector2D(0, 0);
    qreal m_frictionStrenght = 0;
    bool m_exclusion = true;
    qreal m_speedMultiplier = 1;
};

#endif // ZONEPARAMETER_H

