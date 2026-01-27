#ifndef PATTOUNX_ZONE_H
#define PATTOUNX_ZONE_H

#include <QObject>
#include <QVector2D>
#include <QVariantList>
#include <QString>
#include "collision2d.h"
#include "game/item_snapable/ItemSnapable.h"

/**
 * @brief Zone physique 2D avec effets
 * 
 * Représente une zone polygonale qui peut avoir différents effets
 * sur les entités physiques qui la traversent.
 */
class PattounX_zone : public QObject
{
    Q_OBJECT
    
    Q_PROPERTY(QString zoneId READ zoneId CONSTANT)
    Q_PROPERTY(bool isActive READ isActive  NOTIFY isActiveChanged FINAL)
 
public:
    explicit PattounX_zone(ItemSnapable* snapable, QObject* parent = nullptr);
    
    // --- Getters ---
    QString zoneId() const;
    bool isActive() const { return m_isActive; }
    bool exclusion() const;

    ItemSnapable* snapable() const { return m_snapable; }
    ZoneParameter* zoneParameter() const;

    
    // --- API Publique ---
    
    /**
     * @brief Vérifie si un point est à l'intérieur de la zone
     * @param point Point à tester (coordonnées de grille)
     * @return true si le point est dans la zone
     */
    Q_INVOKABLE bool containsPoint(const QVector2D& point) const;

    /**
     * @brief Vérifie collision cercle-zone
     * @param center Centre du cercle
     * @param radius Rayon du cercle
     * @return Résultat de collision
     */
    CollisionResult checkCollision(const QVector2D& center, qreal radius) const;

    /**
     * @brief Vérifie collision continue cercle-zone (sweep test)
     * @param startPos Position de départ du cercle
     * @param endPos Position d'arrivée du cercle
     * @param radius Rayon du cercle
     * @return Résultat de collision avec paramètre t
     */
    CollisionResult checkCollisionSweep(const QVector2D& startPos, const QVector2D& endPos, qreal radius) const;

    QVector<CollisionResult> checkCollisionAll(const QVector2D& center, qreal radius) const;
    QVector<CollisionResult> checkCollisionSweepAll(const QVector2D& startPos, const QVector2D& endPos, qreal radius) const;

    /**
     * @brief Accès aux paramètres de la zone
     * @return Référence constante vers les paramètres
     */
    const ZoneParameter& getZoneParameters() const;

signals:

    void isActiveChanged();

private slots:
    void updatePolygon();

private:
    ItemSnapable* m_snapable = nullptr;

    Polygon2D m_polygon;            // Version optimisée
    
    bool m_isActive = true;
};

#endif // PATTOUNX_ZONE_H

