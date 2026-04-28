#ifndef PHYSICALOBJECTPARAMETER_H
#define PHYSICALOBJECTPARAMETER_H

#include <QObject>
#include <QJsonObject>

/**
 * Phase 9 (extension post-cleanup) — paramètres physiques d'une caisse
 * `ItemSnapable::PhysicalObjectTile`.
 *
 * Modélisé sur DecorationParameter (QObject + Q_PROPERTY + JSON), pas
 * sur ZoneParameter (qui porte un polygone et beaucoup d'état). Ici on
 * ne tient que les coefficients lus par le moteur Pattounx v2 lors
 * de la création du Body Dynamic. Le rayon reste dérivé du
 * `displayParameter.unitSizeWidth` (cercle inscrit), donc absent de
 * cette classe — le couplage taille_visuelle ↔ rayon_collision est
 * géré par EditorPhysicsBridge.
 */
class PhysicalObjectParameter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(qreal mass            READ mass            WRITE setMass            NOTIFY massChanged)
    Q_PROPERTY(qreal bounceFactor    READ bounceFactor    WRITE setBounceFactor    NOTIFY bounceFactorChanged)
    Q_PROPERTY(qreal frictionStrength READ frictionStrength WRITE setFrictionStrength NOTIFY frictionStrengthChanged)
    Q_PROPERTY(qreal linearDamping   READ linearDamping   WRITE setLinearDamping   NOTIFY linearDampingChanged)

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

    QString toJSON() const;
    void applyJson(const QJsonObject &json);

    bool operator==(const PhysicalObjectParameter &other) const {
        return qFuzzyCompare(m_mass,             other.m_mass)
            && qFuzzyCompare(m_bounceFactor,     other.m_bounceFactor)
            && qFuzzyCompare(m_frictionStrength, other.m_frictionStrength)
            && qFuzzyCompare(m_linearDamping,    other.m_linearDamping);
    }

signals:
    void massChanged();
    void bounceFactorChanged();
    void frictionStrengthChanged();
    void linearDampingChanged();

private:
    qreal m_mass            = 1.0;
    qreal m_bounceFactor    = 0.3;
    qreal m_frictionStrength = 0.4;
    qreal m_linearDamping   = 0.1;
};

#endif // PHYSICALOBJECTPARAMETER_H
