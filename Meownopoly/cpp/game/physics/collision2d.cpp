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

QVector<CollisionResult> Collision2D::checkCirclePolygonAll(
    const QVector2D& center,
    qreal radius,
    const Polygon2D& polygon)
{
    QVector<CollisionResult> results;
    
    if (!polygon.isValid() || !checkCircleAABB(center, radius, polygon.boundingBox)) {
        return results;
    }
    
    for (int i = 0; i < polygon.points.size(); ++i) {
        int j = (i + 1) % polygon.points.size();
        
        SegmentResult segResult = pointToSegmentDistance(
            center,
            polygon.points[i],
            polygon.points[j]
        );
        
        if (segResult.distance < radius) {
            CollisionResult result;
            result.colliding = true;
            result.distance = segResult.distance;
            result.closestPoint = segResult.closestPoint;
            result.penetration = radius - segResult.distance;
            
            QVector2D toCenter = center - segResult.closestPoint;
            if (toCenter.lengthSquared() > EPSILON * EPSILON) {
                result.normal = toCenter.normalized();
            } else {
                result.normal = polygon.normals[i];
            }
            results.append(result);
        }
    }
    
    return results;
}

CollisionResult Collision2D::checkCirclePolygonSweep(
    const QVector2D& startPos,
    const QVector2D& endPos,
    qreal radius,
    const Polygon2D& polygon)
{
    QVector<CollisionResult> all = checkCirclePolygonSweepAll(startPos, endPos, radius, polygon);
    if (all.isEmpty()) return CollisionResult();
    
    // Retourner la plus proche (t minimal)
    CollisionResult best = all[0];
    for (const auto& res : all) {
        if (res.t < best.t) best = res;
    }
    return best;
}

qreal Collision2D::sweepCircleSegment(
    const QVector2D& startPos,
    const QVector2D& endPos,
    qreal radius,
    const QVector2D& segA,
    const QVector2D& segB,
    QVector2D& outClosest,
    QVector2D& outNormal)
{
    // Sweep analytique : on cherche le plus petit t dans [0,1] tel que
    // dist(startPos + t*movement, segment[segA,segB]) == radius
    //
    // Stratégie : tester la collision du rayon de mouvement contre la capsule
    // formée par le segment gonflé du rayon (Minkowski sum).
    // Cela se décompose en :
    //   1) Rayon vs cercle aux extrémités segA et segB (rayon radius)
    //   2) Rayon vs les deux segments parallèles décalés de ±radius*normal

    QVector2D movement = endPos - startPos;
    qreal bestT = -1.0;

    // --- 1. Sweep cercle vs sommets (résolution quadratique) ---
    // Pour un sommet V : |startPos + t*movement - V|² = radius²
    // => |movement|²·t² + 2·dot(startPos-V, movement)·t + |startPos-V|² - r² = 0
    auto sweepCircleVertex = [&](const QVector2D& vertex) {
        QVector2D d = startPos - vertex;
        qreal a = QVector2D::dotProduct(movement, movement);
        qreal b = 2.0 * QVector2D::dotProduct(d, movement);
        qreal c = QVector2D::dotProduct(d, d) - radius * radius;

        qreal discriminant = b * b - 4.0 * a * c;
        if (discriminant < 0 || a < EPSILON * EPSILON) return;

        qreal sqrtDisc = std::sqrt(discriminant);
        qreal t = (-b - sqrtDisc) / (2.0 * a);

        if (t >= -EPSILON && t <= 1.0 + EPSILON) {
            t = std::clamp(t, 0.0, 1.0);
            if (bestT < 0 || t < bestT) {
                bestT = t;
                outClosest = vertex;
                QVector2D hitPos = startPos + t * movement;
                QVector2D toCenter = hitPos - vertex;
                qreal len = toCenter.length();
                outNormal = (len > EPSILON) ? toCenter / len : QVector2D(0, 1);
            }
        }
    };

    sweepCircleVertex(segA);
    sweepCircleVertex(segB);

    // --- 2. Sweep cercle vs segment infini, puis clamp sur [0,L] ---
    QVector2D segDir = segB - segA;
    qreal segLenSq = segDir.lengthSquared();

    if (segLenSq > EPSILON * EPSILON) {
        qreal segLen = std::sqrt(segLenSq);
        QVector2D segNorm(-segDir.y() / segLen, segDir.x() / segLen);

        // On projette le mouvement sur la normale du segment :
        // distance(t) = dot(startPos + t*movement - segA, segNorm)
        // On cherche |distance(t)| == radius
        qreal d0 = QVector2D::dotProduct(startPos - segA, segNorm);
        qreal dv = QVector2D::dotProduct(movement, segNorm);

        // distance(t) = d0 + t*dv
        // d0 + t*dv = ±radius => t = (±radius - d0) / dv
        auto trySegmentSide = [&](qreal targetDist) {
            if (std::abs(dv) < EPSILON) return; // Mouvement parallèle au segment
            qreal t = (targetDist - d0) / dv;

            if (t >= -EPSILON && t <= 1.0 + EPSILON) {
                t = std::clamp(t, 0.0, 1.0);
                QVector2D hitPos = startPos + t * movement;

                // Vérifier que le point de contact est bien sur le segment [0, segLen]
                qreal proj = QVector2D::dotProduct(hitPos - segA, segDir) / segLenSq;
                if (proj >= -EPSILON && proj <= 1.0 + EPSILON) {
                    proj = std::clamp(proj, 0.0, 1.0);
                    if (bestT < 0 || t < bestT) {
                        bestT = t;
                        outClosest = segA + proj * segDir;
                        QVector2D toCenter = hitPos - outClosest;
                        qreal len = toCenter.length();
                        outNormal = (len > EPSILON) ? toCenter / len : segNorm;
                    }
                }
            }
        };

        trySegmentSide(radius);
        trySegmentSide(-radius);
    }

    return bestT;
}

QVector<CollisionResult> Collision2D::checkCirclePolygonSweepAll(
    const QVector2D& startPos,
    const QVector2D& endPos,
    qreal radius,
    const Polygon2D& polygon)
{
    QVector<CollisionResult> results;

    if (!polygon.isValid()) return results;

    QVector2D movement = endPos - startPos;
    qreal movementLength = movement.length();

    if (movementLength < EPSILON) {
        return checkCirclePolygonAll(startPos, radius, polygon);
    }

    // Test AABB étendu (broadphase rapide)
    QRectF extendedBox = polygon.boundingBox.adjusted(-radius, -radius, radius, radius);
    QRectF movementBox(
        std::min(startPos.x(), endPos.x()) - radius,
        std::min(startPos.y(), endPos.y()) - radius,
        std::abs(endPos.x() - startPos.x()) + 2 * radius,
        std::abs(endPos.y() - startPos.y()) + 2 * radius
    );

    if (!movementBox.intersects(extendedBox)) return results;

    // Pour chaque segment du polygone, sweep analytique
    for (int i = 0; i < polygon.points.size(); ++i) {
        int j = (i + 1) % polygon.points.size();

        QVector2D closest, normal;
        qreal t = sweepCircleSegment(startPos, endPos, radius, polygon.points[i], polygon.points[j], closest, normal);

        if (t >= 0.0) {
            CollisionResult result;
            result.colliding = true;
            result.t = t;
            result.closestPoint = closest;
            result.normal = normal;

            QVector2D hitPos = startPos + t * movement;
            result.distance = (hitPos - closest).length();
            result.penetration = radius - result.distance;
            if (result.penetration < 0) result.penetration = 0;

            results.append(result);
        }
    }

    return results;
}

qreal Collision2D::sweepCircleCircle(
    const QVector2D& startA,
    const QVector2D& endA,
    qreal radiusA,
    const QVector2D& startB,
    const QVector2D& endB,
    qreal radiusB,
    QVector2D& outNormal)
{
    // Mouvement relatif : on traite A comme statique en posant
    //   relStart = startA - startB ; relMov = (endA - startA) - (endB - startB)
    // On cherche le plus petit t dans [0,1] tel que
    //   |relStart + t*relMov|² = (rA + rB)²
    QVector2D relStart = startA - startB;
    QVector2D movA = endA - startA;
    QVector2D movB = endB - startB;
    QVector2D relMov = movA - movB;

    qreal r = radiusA + radiusB;

    qreal a = QVector2D::dotProduct(relMov, relMov);
    qreal b = 2.0 * QVector2D::dotProduct(relStart, relMov);
    qreal c = QVector2D::dotProduct(relStart, relStart) - r * r;

    // Déjà en interpénétration au temps 0 : on déclenche un contact à t=0
    if (c <= 0) {
        qreal len = relStart.length();
        outNormal = (len > EPSILON) ? relStart / len : QVector2D(1, 0);
        return 0.0;
    }

    // Mouvement relatif négligeable et pas de pénétration → pas de collision
    if (a < EPSILON * EPSILON) {
        return -1.0;
    }

    qreal disc = b * b - 4.0 * a * c;
    if (disc < 0) return -1.0;

    qreal sqrtDisc = std::sqrt(disc);
    qreal t = (-b - sqrtDisc) / (2.0 * a);

    if (t < -EPSILON || t > 1.0 + EPSILON) return -1.0;
    t = std::clamp(t, 0.0, 1.0);

    QVector2D contactRel = relStart + t * relMov;
    qreal len = contactRel.length();
    outNormal = (len > EPSILON) ? contactRel / len : QVector2D(1, 0);
    return t;
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

