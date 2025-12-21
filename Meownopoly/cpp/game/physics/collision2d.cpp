#include "collision2d.h"
#include <algorithm>
#include <limits>

// ==================== Polygon2D ====================

Polygon2D Polygon2D::fromVariantList(const QVariantList& variantPoints)
{
    Polygon2D polygon;
    polygon.points.reserve(variantPoints.size());
    
    for (const QVariant& var : variantPoints) {
        QVariantMap pointMap = var.toMap();
        qreal x = pointMap.value("x", 0.0).toReal();
        qreal y = pointMap.value("y", 0.0).toReal();
        polygon.points.append(QVector2D(x, y));
    }
    
    polygon.computeCache();
    return polygon;
}

void Polygon2D::computeCache()
{
    if (points.size() < 3) return;
    
    // Calculer la bounding box
    qreal minX = std::numeric_limits<qreal>::max();
    qreal minY = std::numeric_limits<qreal>::max();
    qreal maxX = std::numeric_limits<qreal>::lowest();
    qreal maxY = std::numeric_limits<qreal>::lowest();
    
    for (const QVector2D& p : points) {
        minX = std::min(minX, static_cast<qreal>(p.x()));
        minY = std::min(minY, static_cast<qreal>(p.y()));
        maxX = std::max(maxX, static_cast<qreal>(p.x()));
        maxY = std::max(maxY, static_cast<qreal>(p.y()));
    }
    
    boundingBox = QRectF(minX, minY, maxX - minX, maxY - minY);
    
    // Calculer les normales des segments
    normals.clear();
    normals.reserve(points.size());
    
    for (int i = 0; i < points.size(); ++i) {
        int j = (i + 1) % points.size();
        QVector2D edge = points[j] - points[i];
        qreal length = edge.length();
        
        if (length > Collision2D::EPSILON) {
            // Normale perpendiculaire au segment (sens horaire)
            QVector2D normal(-edge.y() / length, edge.x() / length);
            normals.append(normal);
        } else {
            normals.append(QVector2D(0, 0));
        }
    }
}

// ==================== Collision2D ====================

SegmentResult Collision2D::pointToSegmentDistance(
    const QVector2D& point,
    const QVector2D& segStart,
    const QVector2D& segEnd)
{
    SegmentResult result;
    
    QVector2D segment = segEnd - segStart;
    qreal lengthSq = segment.lengthSquared();
    
    // Segment dégénéré (point)
    if (lengthSq < EPSILON * EPSILON) {
        result.closestPoint = segStart;
        result.distance = (point - segStart).length();
        result.t = 0.0;
        return result;
    }
    
    // Projection du point sur la ligne
    qreal t = QVector2D::dotProduct(point - segStart, segment) / lengthSq;
    
    // Clamper t dans [0, 1] pour rester sur le segment
    result.t = std::clamp(t, 0.0, 1.0);
    
    // Calculer le point le plus proche
    result.closestPoint = segStart + result.t * segment;
    result.distance = (point - result.closestPoint).length();
    
    return result;
}

bool Collision2D::checkCircleAABB(
    const QVector2D& center,
    qreal radius,
    const QRectF& box)
{
    // Trouver le point le plus proche dans la box
    qreal closestX = std::clamp(static_cast<qreal>(center.x()), box.left(), box.right());
    qreal closestY = std::clamp(static_cast<qreal>(center.y()), box.top(), box.bottom());
    
    // Calculer la distance au carré
    qreal dx = center.x() - closestX;
    qreal dy = center.y() - closestY;
    qreal distSq = dx * dx + dy * dy;
    
    return distSq <= radius * radius;
}

CollisionResult Collision2D::checkCirclePolygon(
    const QVector2D& center,
    qreal radius,
    const Polygon2D& polygon)
{
    CollisionResult result;
    
    if (!polygon.isValid()) {
        return result;
    }
    
    // Test rapide avec bounding box
    if (!checkCircleAABB(center, radius, polygon.boundingBox)) {
        return result;
    }
    
    // Trouver le segment le plus proche
    qreal minDist = std::numeric_limits<qreal>::max();
    QVector2D closestPoint;
    QVector2D segmentNormal;
    
    for (int i = 0; i < polygon.points.size(); ++i) {
        int j = (i + 1) % polygon.points.size();
        
        SegmentResult segResult = pointToSegmentDistance(
            center,
            polygon.points[i],
            polygon.points[j]
        );
        
        if (segResult.distance < minDist) {
            minDist = segResult.distance;
            closestPoint = segResult.closestPoint;
            segmentNormal = polygon.normals[i];
        }
    }
    
    // Pas de collision si distance > rayon
    if (minDist >= radius) {
        return result;
    }
    
    // Calculer la normale de collision (du mur vers le cercle)
    QVector2D toCenter = center - closestPoint;
    qreal toCenterLen = toCenter.length();
    
    QVector2D normal;
    if (toCenterLen > EPSILON) {
        normal = toCenter / toCenterLen;
    } else {
        // Centre exactement sur le segment, utiliser la normale du segment
        normal = segmentNormal;
    }
    
    // Remplir le résultat
    result.colliding = true;
    result.distance = minDist;
    result.normal = normal;
    result.closestPoint = closestPoint;
    result.penetration = radius - minDist;
    
    return result;
}

bool Collision2D::pointInPolygon(
    const QVector2D& point,
    const Polygon2D& polygon)
{
    if (!polygon.isValid()) {
        return false;
    }
    
    // Test rapide avec bounding box
    if (!polygon.boundingBox.contains(point.x(), point.y())) {
        return false;
    }
    
    // Algorithme du ray casting
    bool inside = false;
    int n = polygon.points.size();
    
    for (int i = 0, j = n - 1; i < n; j = i++) {
        const QVector2D& pi = polygon.points[i];
        const QVector2D& pj = polygon.points[j];
        
        if (((pi.y() > point.y()) != (pj.y() > point.y())) &&
            (point.x() < (pj.x() - pi.x()) * (point.y() - pi.y()) / (pj.y() - pi.y()) + pi.x()))
        {
            inside = !inside;
        }
    }
    
    return inside;
}

CollisionResult Collision2D::checkCirclePolygonSweep(
    const QVector2D& startPos,
    const QVector2D& endPos,
    qreal radius,
    const Polygon2D& polygon)
{
    CollisionResult result;

    if (!polygon.isValid()) {
        return result;
    }

    // Vecteur de mouvement
    QVector2D movement = endPos - startPos;
    qreal movementLength = movement.length();

    // Si pas de mouvement, utiliser le test statique
    if (movementLength < EPSILON) {
        return checkCirclePolygon(startPos, radius, polygon);
    }

    // Test rapide avec bounding box étendue
    QRectF extendedBox = polygon.boundingBox;
    extendedBox.adjust(-radius, -radius, radius, radius);

    // Créer la bounding box du segment de mouvement
    QRectF movementBox(
        std::min(startPos.x(), endPos.x()) - radius,
        std::min(startPos.y(), endPos.y()) - radius,
        std::abs(endPos.x() - startPos.x()) + 2 * radius,
        std::abs(endPos.y() - startPos.y()) + 2 * radius
    );

    if (!movementBox.intersects(extendedBox)) {
        return result;
    }

    // Nombre d'étapes adaptatif basé sur la longueur du mouvement et le rayon
    // Plus le mouvement est long ou le rayon petit, plus d'étapes pour éviter le tunneling
    const int MIN_STEPS = 4;
    const int MAX_STEPS = 50;
    const qreal BASE_STEPS_PER_UNIT = 8.0; // étapes de base par unité de longueur
    const qreal RADIUS_FACTOR = 1.0 / radius; // plus le rayon est petit, plus d'étapes

    qreal adaptiveStepsPerUnit = BASE_STEPS_PER_UNIT * std::max(1.0, RADIUS_FACTOR * 0.5);
    int steps = std::clamp(static_cast<int>(movementLength * adaptiveStepsPerUnit),
                          MIN_STEPS, MAX_STEPS);

    qreal earliestT = 2.0; // > 1.0 pour indiquer pas de collision trouvée
    QVector2D earliestNormal;
    QVector2D earliestPoint;
    qreal earliestPenetration = 0.0;

    // Tester les positions intermédiaires (exclure le point de départ)
    for (int step = 1; step <= steps; ++step) {
        qreal t = static_cast<qreal>(step) / steps;
        QVector2D testPos = startPos + t * movement;

        // Tester la collision statique à cette position
        CollisionResult staticResult = checkCirclePolygon(testPos, radius, polygon);

        if (staticResult.colliding && t < earliestT) {
            qDebug() << "[Collision2D]  staticResult t : " << t << testPos << staticResult.colliding;
            earliestT = t;
            earliestNormal = staticResult.normal;
            earliestPoint = staticResult.closestPoint;
            earliestPenetration = staticResult.penetration;
        }
    }

    // Si on a trouvé une collision
    if (earliestT <= 1.0) {
        qDebug() << "[Collision2D]  collision t : "<< earliestT;
        result.colliding = true;
        result.t = std::clamp(earliestT, 0.0, 1.0); // S'assurer que t est dans [0,1]
        result.closestPoint = earliestPoint;
        result.normal = earliestNormal;
        result.penetration = earliestPenetration;

        // Calculer la distance correcte à la position d'impact
        QVector2D impactPos = startPos + result.t * movement;
        result.distance = (impactPos - earliestPoint).length();
    }

    return result;
}

QVector2D Collision2D::applyBounce(
    const QVector2D& velocity,
    const QVector2D& normal,
    qreal bounceFactor,
    qreal slideFactor)
{
    // Produit scalaire vitesse . normale
    qreal dot = QVector2D::dotProduct(velocity, normal);

    // Si la vitesse va déjà vers l'extérieur, pas de rebond
    if (dot >= 0) {
        return velocity;
    }

    // Composante perpendiculaire (vers le mur)
    QVector2D perpendicular = dot * normal;

    // Composante parallèle (le long du mur)
    QVector2D parallel = velocity - perpendicular;

    // Nouvelle vitesse : rebond de la composante perpendiculaire + glissement
    QVector2D newVelocity = -perpendicular * bounceFactor + parallel * slideFactor;

    return newVelocity;
}

