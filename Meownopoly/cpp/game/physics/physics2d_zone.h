#ifndef PHYSICS2D_ZONE_H
#define PHYSICS2D_ZONE_H

#include <QObject>
#include <QVector2D>
#include <QVariantList>
#include <QString>
#include "collision2d.h"

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
    Q_PROPERTY(ZoneType zoneType READ zoneType WRITE setZoneType NOTIFY zoneTypeChanged)
    Q_PROPERTY(QVariantList polygon READ polygon WRITE setPolygon NOTIFY polygonChanged)
    Q_PROPERTY(qreal effectStrength READ effectStrength WRITE setEffectStrength NOTIFY effectStrengthChanged)
    Q_PROPERTY(QVector2D effectDirection READ effectDirection WRITE setEffectDirection NOTIFY effectDirectionChanged)
    Q_PROPERTY(bool isActive READ isActive WRITE setIsActive NOTIFY isActiveChanged)
    Q_PROPERTY(QString zoneName READ zoneName WRITE setZoneName NOTIFY zoneNameChanged)
    Q_PROPERTY(QString zoneColor READ zoneColor WRITE setZoneColor NOTIFY zoneColorChanged)

public:
    /**
     * @brief Types de zones physiques
     */
    enum ZoneType {
        Exclusion = 0,      ///< Zone solide avec collision et rebond
        SpeedBoost,         ///< Zone augmentant la vitesse
        SpeedSlow,          ///< Zone ralentissant le mouvement
        IceZone,            ///< Zone glissante (friction réduite)
        ConveyorBelt,       ///< Zone avec force directionnelle
        JumpPad,            ///< Zone de saut (impulsion verticale)
        DamageZone,         ///< Zone infligeant des dégâts
        HealZone            ///< Zone de soin
    };
    Q_ENUM(ZoneType)
    
    explicit PhysicsZone2D(QObject* parent = nullptr);
    explicit PhysicsZone2D(const QString& id, ZoneType type = Exclusion, QObject* parent = nullptr);
    
    // --- Getters ---
    QString zoneId() const { return m_zoneId; }
    ZoneType zoneType() const { return m_zoneType; }
    QVariantList polygon() const { return m_polygonVariant; }
    qreal effectStrength() const { return m_effectStrength; }
    QVector2D effectDirection() const { return m_effectDirection; }
    bool isActive() const { return m_isActive; }
    QString zoneName() const { return m_zoneName; }
    QString zoneColor() const { return m_zoneColor; }
    
    // --- Setters ---
    void setZoneType(ZoneType type);
    void setPolygon(const QVariantList& points);
    void setEffectStrength(qreal strength);
    void setEffectDirection(const QVector2D& direction);
    void setIsActive(bool active);
    void setZoneName(const QString& name);
    void setZoneColor(const QString& color);
    
    // --- API Publique ---
    
    /**
     * @brief Vérifie si un point est à l'intérieur de la zone
     * @param point Point à tester (coordonnées de grille)
     * @return true si le point est dans la zone
     */
    Q_INVOKABLE bool containsPoint(const QVector2D& point) const;
    
    /**
     * @brief Retourne le multiplicateur d'effet selon le type de zone
     * @return Multiplicateur (1.0 = pas d'effet)
     */
    Q_INVOKABLE qreal getEffectMultiplier() const;
    
    /**
     * @brief Retourne le modificateur de friction selon le type de zone
     * @return Multiplicateur de friction (1.0 = normal, <1 = glissant)
     */
    Q_INVOKABLE qreal getFrictionModifier() const;
    
    /**
     * @brief Vérifie collision cercle-zone
     * @param center Centre du cercle
     * @param radius Rayon du cercle
     * @return Résultat de collision
     */
    CollisionResult checkCollision(const QVector2D& center, qreal radius) const;
    
    /**
     * @brief Accès direct au polygone optimisé (usage interne)
     */
    const Polygon2D& getPolygon2D() const { return m_polygon; }

signals:
    void zoneTypeChanged();
    void polygonChanged();
    void effectStrengthChanged();
    void effectDirectionChanged();
    void isActiveChanged();
    void zoneNameChanged();
    void zoneColorChanged();

private:
    QString m_zoneId;
    ZoneType m_zoneType = Exclusion;
    QVariantList m_polygonVariant;  // Pour QML
    Polygon2D m_polygon;            // Version optimisée
    qreal m_effectStrength = 1.0;
    QVector2D m_effectDirection;
    bool m_isActive = true;
    QString m_zoneName;
    QString m_zoneColor = "#FF5722";
};

#endif // PHYSICS2D_ZONE_H

