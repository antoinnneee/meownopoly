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
    Q_PROPERTY(qreal velocityStrength READ velocityStrength WRITE setVelocityStrength NOTIFY velocityStrengthChanged FINAL)
    Q_PROPERTY(qreal frictionStrength READ frictionStrength WRITE setFrictionStrength NOTIFY frictionStrengthChanged FINAL)
    Q_PROPERTY(qreal speedMultiplier READ speedMultiplier WRITE setSpeedMultiplier NOTIFY speedMultiplierChanged FINAL)
    Q_PROPERTY(bool exclusion READ exclusion WRITE setExclusion NOTIFY exclusionChanged FINAL)
    Q_PROPERTY(qreal accelerationMultiplier READ accelerationMultiplier WRITE setAccelerationMultiplier NOTIFY accelerationMultiplierChanged FINAL)
    // Référence (id) vers un ScreenEffect de la bibliothèque de la carte
    // (MapInfo::screenEffects). Vide = aucun effet visuel à l'entrée de zone.
    Q_PROPERTY(QString screenEffectId READ screenEffectId WRITE setScreenEffectId NOTIFY screenEffectIdChanged FINAL)
    // Déclencheur "plaque de pression" (zones NON-exclusion uniquement) :
    // 0 = aucun, 1 = plaque de pression (activée quand une caisse
    // PhysicalObjectTile est dans la zone). À l'activation : les éléments
    // liés (next) sont "ouverts" (zone d'exclusion retirée du moteur,
    // décoration estompée) et la récompense éventuelle est créditée via les
    // modules de gameplay. Cf. TriggerController.qml.
    Q_PROPERTY(int triggerMode READ triggerMode WRITE setTriggerMode NOTIFY triggerModeChanged FINAL)
    // true = l'activation est permanente (latch) ; false = la porte se
    // referme quand la caisse quitte la zone (la récompense reste one-shot).
    Q_PROPERTY(bool triggerOnce READ triggerOnce WRITE setTriggerOnce NOTIFY triggerOnceChanged FINAL)
    Q_PROPERTY(int rewardCurrency READ rewardCurrency WRITE setRewardCurrency NOTIFY rewardCurrencyChanged FINAL)
    Q_PROPERTY(QString rewardItemName READ rewardItemName WRITE setRewardItemName NOTIFY rewardItemNameChanged FINAL)
    Q_PROPERTY(int rewardItemQuantity READ rewardItemQuantity WRITE setRewardItemQuantity NOTIFY rewardItemQuantityChanged FINAL)

public:

    // bool operator==(const ZoneParameter &other) const;

    bool operator==(const ZoneParameter &other) const {
        qDebug() << "Comparing ZoneParameter with zoneName:" << zoneName() << "to ZoneParameter with zoneName:" << other.zoneName();
        return m_polygonPoints         == other.m_polygonPoints
               && m_zoneColor             == other.m_zoneColor
               && m_zoneName              == other.m_zoneName
               && m_velocityDirection     == other.m_velocityDirection
               && m_velocityStrength      == other.m_velocityStrength
               && m_frictionStrength      == other.m_frictionStrength
               && m_exclusion             == other.m_exclusion
               && m_speedMultiplier       == other.m_speedMultiplier
               && m_accelerationMultiplier == other.m_accelerationMultiplier
               && m_screenEffectId        == other.m_screenEffectId
               && m_triggerMode           == other.m_triggerMode
               && m_triggerOnce           == other.m_triggerOnce
               && m_rewardCurrency        == other.m_rewardCurrency
               && m_rewardItemName        == other.m_rewardItemName
               && m_rewardItemQuantity    == other.m_rewardItemQuantity;
    }

    explicit ZoneParameter(QObject *parent = nullptr);
    explicit ZoneParameter(const QJsonObject &json, QObject *parent = nullptr);
    explicit ZoneParameter(const ZoneParameter &other, QObject *parent = nullptr);
    QString toJSON();
    QJsonObject toJsonObject() const;
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

    qreal velocityStrength() const;
    void setVelocityStrength(qreal newVelocityStrength);



    qreal frictionStrength() const;
    void setFrictionStrength(qreal newFrictionStrength);

    bool exclusion() const;
    void setExclusion(bool newExclusion);

    qreal speedMultiplier() const;
    void setSpeedMultiplier(qreal newSpeedMultiplier);

    qreal accelerationMultiplier() const;
    void setAccelerationMultiplier(qreal newAccelerationMultiplier);

    QString screenEffectId() const;
    void setScreenEffectId(const QString &newScreenEffectId);

    int triggerMode() const { return m_triggerMode; }
    void setTriggerMode(int newTriggerMode);

    bool triggerOnce() const { return m_triggerOnce; }
    void setTriggerOnce(bool newTriggerOnce);

    int rewardCurrency() const { return m_rewardCurrency; }
    void setRewardCurrency(int newRewardCurrency);

    QString rewardItemName() const { return m_rewardItemName; }
    void setRewardItemName(const QString &newRewardItemName);

    int rewardItemQuantity() const { return m_rewardItemQuantity; }
    void setRewardItemQuantity(int newRewardItemQuantity);



signals:
    void polygonPointsChanged();
    void zoneColorChanged();
    void zoneNameChanged();

    void velocityDirectionChanged();

    void velocityStrengthChanged();



    void frictionStrengthChanged();

    void exclusionChanged();

    void speedMultiplierChanged();

    void accelerationMultiplierChanged();

    void screenEffectIdChanged();
    void triggerModeChanged();
    void triggerOnceChanged();
    void rewardCurrencyChanged();
    void rewardItemNameChanged();
    void rewardItemQuantityChanged();

private:
    QVariantList m_polygonPoints;
    QString m_zoneColor;
    QString m_zoneName;
    QVector2D m_velocityDirection = QVector2D(0, 0);
    qreal m_velocityStrength = 0;
    qreal m_frictionStrength = 0;
    bool m_exclusion = true;
    qreal m_speedMultiplier = 1;
    qreal m_accelerationMultiplier = 1;
    QString m_screenEffectId;
    int m_triggerMode = 0;          // 0 = None, 1 = PressurePlate
    bool m_triggerOnce = false;
    int m_rewardCurrency = 0;
    QString m_rewardItemName;
    int m_rewardItemQuantity = 1;
};

#endif // ZONEPARAMETER_H

