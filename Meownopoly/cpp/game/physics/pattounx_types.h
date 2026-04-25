/*
 *      PattounX v2 — types POD partagés
 *
 * Définitions Qt-free (au sens : pas de QObject, pas de signaux). Utilise
 * QString/QVector/QHash/QVector2D pour rester intégré à l'écosystème Qt
 * sans coupler à un thread ou à un cycle de signaux.
 */
#ifndef PATTOUNX_TYPES_H
#define PATTOUNX_TYPES_H

#include <QHash>
#include <QMetaType>
#include <QString>
#include <QVector>
#include <QVector2D>
#include <cstdint>
#include <utility>

namespace pattounx {

enum class BodyType : uint8_t {
    Static,    // immobile, pas d'intégration
    Kinematic, // input-driven (joueur), ignore forces externes
    Dynamic,   // simulé : forces, masse, collisions body-body (caisse)
};

enum class ShapeType : uint8_t {
    Circle,
    Polygon,
};

struct ShapeSpec
{
    ShapeType type = ShapeType::Circle;
    qreal radius = 0.2;
    QVector<QVector2D> polygonPoints; // absolus, en grille
};

struct BodySpec
{
    QString id;
    BodyType type = BodyType::Kinematic;
    ShapeSpec shape;
    QVector2D position;
    qreal mass = 1.0;
    qreal acceleration = 30.0;
    qreal maxSpeed = 300.0;
    qreal bounceFactor = 0.1;
    qreal slideFactor = 1.0;
    qreal linearDamping = 0.1;
    qreal staticFriction = 0.4;
    qreal dynamicFriction = 0.2;
    qreal restitution = 0.3;
};

struct ZoneSpec
{
    QString id;
    QVector<QVector2D> polygon; // points absolus en grille
    bool exclusion = false;
    bool trigger = true;
    qreal frictionStrength = 0.5;
    qreal accelerationMultiplier = 1.0;
    qreal speedMultiplier = 1.0;
    QVector2D velocityForce { 0.0f, 0.0f };
};

struct BodySnapshot
{
    QString id;
    QVector2D position;
    QVector2D velocity;
    bool isSleeping = false;
    bool isColliding = false;
};

struct WorldSnapshot
{
    quint64 tick = 0;
    qint64 timestampNs = 0;
    QHash<QString, BodySnapshot> bodies;
};

} // namespace pattounx

Q_DECLARE_METATYPE(pattounx::BodySpec)
Q_DECLARE_METATYPE(pattounx::ZoneSpec)
Q_DECLARE_METATYPE(pattounx::BodySnapshot)
Q_DECLARE_METATYPE(pattounx::WorldSnapshot)

#endif // PATTOUNX_TYPES_H
