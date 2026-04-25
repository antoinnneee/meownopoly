#ifndef COLLISION2D_H
#define COLLISION2D_H

#include <QObject>
#include <QVector2D>
#include <QVector>
#include <QRectF>
#include <QVariantList>
#include <cmath>

// Forward declaration
class PattounX_zone;
class PattounX_body;
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
    qreal t = 1.0;                  // Paramètre d'intersection [0,1] pour sweep tests
    PattounX_zone* zone = nullptr;  // Zone touchée (si applicable)
    PattounX_body* body = nullptr;  // Body touché (si applicable)
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
     * @brief Vérifie la collision d'un cercle en mouvement avec un polygone (sweep test)
     * @param startPos Position de départ du cercle
     * @param endPos Position d'arrivée du cercle
     * @param radius Rayon du cercle
     * @param polygon Polygone à tester
     * @return CollisionResult avec t indiquant le moment de collision [0,1]
     *
     * Cette fonction effectue une détection de collision continue le long
     * du segment de mouvement, évitant le problème de tunneling à haute vitesse.
     */
    static CollisionResult checkCirclePolygonSweep(
        const QVector2D& startPos,
        const QVector2D& endPos,
        qreal radius,
        const Polygon2D& polygon
    );

    /**
     * @brief Version retournant toutes les collisions trouvées sur le polygone
     */
    static QVector<CollisionResult> checkCirclePolygonAll(
        const QVector2D& center,
        qreal radius,
        const Polygon2D& polygon
    );

    static QVector<CollisionResult> checkCirclePolygonSweepAll(
        const QVector2D& startPos,
        const QVector2D& endPos,
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
     * @brief Sweep analytique cercle vs segment (résolution quadratique)
     * @param startPos Position de départ du cercle
     * @param endPos Position d'arrivée du cercle
     * @param radius Rayon du cercle
     * @param segA Début du segment
     * @param segB Fin du segment
     * @param outNormal Normale de collision (sortie)
     * @return t dans [0,1] de la première collision, ou -1 si aucune
     */
    static qreal sweepCircleSegment(
        const QVector2D& startPos,
        const QVector2D& endPos,
        qreal radius,
        const QVector2D& segA,
        const QVector2D& segB,
        QVector2D& outClosest,
        QVector2D& outNormal
    );

    /**
     * @brief Sweep analytique cercle vs cercle (deux cercles en mouvement).
     * @param startA Position de départ du cercle A
     * @param endA Position d'arrivée du cercle A
     * @param radiusA Rayon du cercle A
     * @param startB Position de départ du cercle B
     * @param endB Position d'arrivée du cercle B
     * @param radiusB Rayon du cercle B
     * @param outNormal Normale de collision au point d'impact, du cercle B vers A
     * @return t dans [0,1] de la première collision, ou -1 si aucune
     *
     * Résolution : on cherche t tel que |P_A(t) - P_B(t)| = r_A + r_B avec
     * P_X(t) = startX + t*(endX - startX). Cela aboutit à une équation
     * quadratique en t. La plus petite racine dans [0,1] est retournée.
     * Si les deux cercles sont déjà en interpénétration à t=0 (cas où les
     * positions de départ sont déjà trop proches), on retourne 0.
     */
    static qreal sweepCircleCircle(
        const QVector2D& startA,
        const QVector2D& endA,
        qreal radiusA,
        const QVector2D& startB,
        const QVector2D& endB,
        qreal radiusB,
        QVector2D& outNormal
    );

    /**
     * @brief Constantes pour les calculs
     */
    static constexpr qreal EPSILON = 0.0001;
};

#endif // COLLISION2D_H

