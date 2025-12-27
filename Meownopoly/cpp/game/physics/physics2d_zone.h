#ifndef PHYSICS2D_ZONE_H
#define PHYSICS2D_ZONE_H

#include <QObject>
#include <QVector2D>
#include <QVariantList>
#include <QString>
#include "collision2d.h"
#include "game/item_snapable/ZoneParameter.h"

/**
 * @brief Zone physique 2D avec effets
 * 
 * Représente une zone polygonale qui peut avoir différents effets
 * sur les entités physiques qui la traversent.
 */
class PhysicsZone2D : public QObject
{
    Q_OBJECT
    
    Q_PROPERTY(QString zoneId READ zoneId CONSTANT)
    Q_PROPERTY(bool isActive READ isActive  NOTIFY isActiveChanged FINAL)
 
public:
    /**
     * @brief Types de zones physiques
     */
    enum ZoneType {
        Zone_Exclusion = 0,      ///< Zone solide avec collision et rebond
        Zone_Speed,          ///< Zone ralentissant le mouvement
        Zone_Friction            ///< Zone glissante (friction réduite)
    };
    Q_ENUM(ZoneType)
    
    explicit PhysicsZone2D(const QString& id, QObject* parent = nullptr);
    explicit PhysicsZone2D(const QString& id,  ZoneParameter& zoneParameter, QObject* parent = nullptr);
    
    // --- Getters ---
    QString zoneId() const { return m_zoneId; }
    bool isActive() const { return m_isActive; }
    bool exclusion() const { return m_zoneParameter.exclusion();};

    
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

    /**
     * @brief Accès aux paramètres de la zone
     * @return Référence constante vers les paramètres
     */
    const ZoneParameter& getZoneParameters() const { return m_zoneParameter; }

signals:

    void isActiveChanged();

private:
    QString m_zoneId;
    ZoneParameter m_zoneParameter;

    Polygon2D m_polygon;            // Version optimisée
    
    bool m_isActive = true;
};

#endif // PHYSICS2D_ZONE_H

