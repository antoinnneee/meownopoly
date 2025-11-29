#ifndef EXCLUSIONPARAMETER_H
#define EXCLUSIONPARAMETER_H

#include <QObject>
#include <QPointF>
#include <QVariantList>
#include <QJsonObject>
#include <QJsonArray>

class ExclusionParameter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString zoneColor READ zoneColor WRITE setZoneColor NOTIFY zoneColorChanged)
    Q_PROPERTY(QString zoneName READ zoneName WRITE setZoneName NOTIFY zoneNameChanged)
    Q_PROPERTY(QVariantList polygonPoints READ polygonPoints WRITE setPolygonPoints NOTIFY polygonPointsChanged)
public:
    explicit ExclusionParameter(QObject *parent = nullptr);
    explicit ExclusionParameter(const QJsonObject &json, QObject *parent = nullptr);
    QString toJSON();
    
    // Liste des points du polygone (en coordonnées de grille)
    Q_PROPERTY(QVariantList polygonPoints READ polygonPoints WRITE setPolygonPoints NOTIFY polygonPointsChanged)
    
    // Couleur de la zone (pour différencier les zones)
    Q_PROPERTY(QString zoneColor READ zoneColor WRITE setZoneColor NOTIFY zoneColorChanged)
    
    // Nom optionnel de la zone
    Q_PROPERTY(QString zoneName READ zoneName WRITE setZoneName NOTIFY zoneNameChanged)

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

signals:
    void polygonPointsChanged();
    void zoneColorChanged();
    void zoneNameChanged();

private:
    QVariantList m_polygonPoints;
    QString m_zoneColor;
    QString m_zoneName;
};

#endif // EXCLUSIONPARAMETER_H

