#ifndef PHYSICALOBJECTPARAMETER_H
#define PHYSICALOBJECTPARAMETER_H

#include <QObject>
#include <QJsonObject>

/**
 * Paramètres physiques d'une caisse / objet dynamique poussable.
 *
 * ⚠️ ACTUELLEMENT NON CÂBLÉ. La feature « caisses » (PhysicalObjectTile,
 * SnapablePhysicalObject, PhysicsObjectSpawner, le chemin objet de
 * EditorPhysicsBridge) a été retirée. Cette classe est **conservée
 * volontairement comme brique réutilisable** pour une future ré-intégration
 * d'objets physiques dans l'éditeur. Elle compile en standalone mais n'est
 * référencée par aucun ItemSnapable pour l'instant.
 *
 * Conçue sur le modèle de DecorationParameter (QObject + Q_PROPERTY + JSON) :
 * elle ne porte que les coefficients lus par le moteur Pattounx v2 à la
 * création d'un Body Dynamic (mass, bounce, friction, damping). Le rayon de
 * collision n'y figure pas — dans l'ancienne intégration il était dérivé de
 * `displayParameter.unitSizeWidth` (cercle inscrit).
 */
class PhysicalObjectParameter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(qreal mass            READ mass            WRITE setMass            NOTIFY massChanged)
    Q_PROPERTY(qreal bounceFactor    READ bounceFactor    WRITE setBounceFactor    NOTIFY bounceFactorChanged)
    Q_PROPERTY(qreal frictionStrength READ frictionStrength WRITE setFrictionStrength NOTIFY frictionStrengthChanged)
    Q_PROPERTY(qreal linearDamping   READ linearDamping   WRITE setLinearDamping   NOTIFY linearDampingChanged)
    // La caisse peut-elle être saisie (grab) par le joueur en jeu ?
    Q_PROPERTY(bool grabbable        READ grabbable       WRITE setGrabbable       NOTIFY grabbableChanged)

public:
    explicit PhysicalObjectParameter(QObject *parent = nullptr);
    explicit PhysicalObjectParameter(const QJsonObject &json, QObject *parent = nullptr);

    qreal mass() const { return m_mass; }
    void setMass(qreal v);

    qreal bounceFactor() const { return m_bounceFactor; }
    void setBounceFactor(qreal v);

    qreal frictionStrength() const { return m_frictionStrength; }
    void setFrictionStrength(qreal v);

    qreal linearDamping() const { return m_linearDamping; }
    void setLinearDamping(qreal v);

    bool grabbable() const { return m_grabbable; }
    void setGrabbable(bool v);

    QString toJSON() const;
    QJsonObject toJsonObject() const;
    void applyJson(const QJsonObject &json);

    bool operator==(const PhysicalObjectParameter &other) const {
        return qFuzzyCompare(m_mass,             other.m_mass)
            && qFuzzyCompare(m_bounceFactor,     other.m_bounceFactor)
            && qFuzzyCompare(m_frictionStrength, other.m_frictionStrength)
            && qFuzzyCompare(m_linearDamping,    other.m_linearDamping)
            && m_grabbable == other.m_grabbable;
    }

signals:
    void massChanged();
    void bounceFactorChanged();
    void frictionStrengthChanged();
    void linearDampingChanged();
    void grabbableChanged();

private:
    qreal m_mass            = 1.0;
    qreal m_bounceFactor    = 0.3;
    qreal m_frictionStrength = 0.4;
    qreal m_linearDamping   = 0.1;
    bool  m_grabbable       = true;
};

#endif // PHYSICALOBJECTPARAMETER_H
