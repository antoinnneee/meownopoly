#ifndef COLLISION2D_H
#define COLLISION2D_H

#include <QObject>
#include <QVector2D>
#include <QVector>
#include <QRectF>
#include <QVariantList>
#include <cmath>

// Forward declaration
class PhysicsZone2D;

/**
 * @brief Structure représentant un polygone optimisé pour la collision
 */
struct Polygon2D {
    QVector<QVector2D> points;      // Points du polygone
    QVector<QVector2D> normals;     // Normales pré-calculées des segments
    QRectF boundingBox;             // Boîte englobante pour optimisation
    
    /**
     * @brief Construit un polygone à partir d'une liste de points QVariant
     */
    static Polygon2D fromVariantList(const QVariantList& points);
    
    /**
     * @brief Recalcule les normales et la bounding box
     */
    void computeCache();
    
    /**
     * @brief Vérifie si le polygone est valide (au moins 3 points)
     */
    bool isValid() const { return points.size() >= 3; }
};

/**
 * @brief Résultat d'une détection de collision
 */
struct CollisionResult {
    bool colliding = false;         // Collision détectée
    qreal distance = 0.0;           // Distance au point le plus proche
    QVector2D normal;               // Normale de collision (pointe vers l'extérieur)
    QVector2D closestPoint;         // Point le plus proche sur le polygone
    qreal penetration = 0.0;        // Profondeur de pénétration
    PhysicsZone2D* zone = nullptr;  // Zone touchée (si applicable)
};

/**
 * @brief Résultat intermédiaire pour distance point-segment
 */
struct SegmentResult {
    qreal distance = 0.0;
    QVector2D closestPoint;
    qreal t = 0.0;  // Paramètre sur le segment [0, 1]
};

/**
 * @brief Système de collision 2D optimisé
 * 
 * Fournit des méthodes statiques pour la détection de collision
 * entre cercles et polygones, avec optimisations (bounding box, etc.)
 */
class Collision2D
{
public:
    /**
     * @brief Calcule la distance d'un point à un segment
     * @param point Point à tester
     * @param segStart Début du segment
     * @param segEnd Fin du segment
     * @return SegmentResult avec distance, point le plus proche, et paramètre t
     */
    static SegmentResult pointToSegmentDistance(
        const QVector2D& point,
        const QVector2D& segStart,
        const QVector2D& segEnd
    );
    
    /**
     * @brief Vérifie si un cercle est en collision avec un polygone
     * @param center Centre du cercle
     * @param radius Rayon du cercle
     * @param polygon Polygone à tester
     * @return CollisionResult avec toutes les informations de collision
     */
    static CollisionResult checkCirclePolygon(
        const QVector2D& center,
        qreal radius,
        const Polygon2D& polygon
    );
    
    /**
     * @brief Test rapide de collision cercle-AABB
     * @param center Centre du cercle
     * @param radius Rayon du cercle
     * @param box Boîte englobante
     * @return true si intersection possible
     */
    static bool checkCircleAABB(
        const QVector2D& center,
        qreal radius,
        const QRectF& box
    );
    
    /**
     * @brief Vérifie si un point est à l'intérieur d'un polygone
     * @param point Point à tester
     * @param polygon Polygone
     * @return true si le point est à l'intérieur
     */
    static bool pointInPolygon(
        const QVector2D& point,
        const Polygon2D& polygon
    );
    
    /**
     * @brief Calcule la nouvelle vitesse après rebond
     * @param velocity Vitesse actuelle
     * @param normal Normale de la surface
     * @param bounceFactor Coefficient de rebond [0, 1]
     * @param slideFactor Coefficient de glissement [0, 1]
     * @return Nouvelle vitesse après rebond
     */
    static QVector2D applyBounce(
        const QVector2D& velocity,
        const QVector2D& normal,
        qreal bounceFactor,
        qreal slideFactor
    );
    
    /**
     * @brief Constantes pour les calculs
     */
    static constexpr qreal EPSILON = 0.0001;
};

#endif // COLLISION2D_H

