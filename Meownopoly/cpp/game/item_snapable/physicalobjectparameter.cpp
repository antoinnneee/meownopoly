#include "physicalobjectparameter.h"

#include <QJsonObject>

PhysicalObjectParameter::PhysicalObjectParameter(QObject *parent)
    : QObject{parent}
{}

PhysicalObjectParameter::PhysicalObjectParameter(const QJsonObject &json, QObject *parent)
    : QObject{parent}
{
    applyJson(json);
}

// Bornes des coefficients physiques. On clampe ici (point unique de passage
// pour l'écriture QML ET le chargement JSON via applyJson) plutôt que dans
// EditorPhysicsBridge : ainsi une valeur aberrante (mass=0, friction<0,
// damping>1…) ne peut jamais atteindre le moteur ni être persistée.
//  - mass : strictement > 0 (un body Dynamic à masse nulle a une invMass
//    infinie → solver d'impulsion qui diverge). Plancher 0.01.
//  - bounceFactor / linearDamping : coefficients normalisés [0, 1].
//  - frictionStrength : coefficient de Coulomb normalisé [0, 1].
void PhysicalObjectParameter::setMass(qreal v)
{
    v = qMax(0.01, v);
    if (qFuzzyCompare(m_mass, v)) return;
    m_mass = v;
    emit massChanged();
}

void PhysicalObjectParameter::setBounceFactor(qreal v)
{
    v = qBound(0.0, v, 1.0);
    if (qFuzzyCompare(m_bounceFactor, v)) return;
    m_bounceFactor = v;
    emit bounceFactorChanged();
}

void PhysicalObjectParameter::setFrictionStrength(qreal v)
{
    v = qBound(0.0, v, 1.0);
    if (qFuzzyCompare(m_frictionStrength, v)) return;
    m_frictionStrength = v;
    emit frictionStrengthChanged();
}

void PhysicalObjectParameter::setLinearDamping(qreal v)
{
    v = qBound(0.0, v, 1.0);
    if (qFuzzyCompare(m_linearDamping, v)) return;
    m_linearDamping = v;
    emit linearDampingChanged();
}

void PhysicalObjectParameter::setGrabbable(bool v)
{
    if (m_grabbable == v) return;
    m_grabbable = v;
    emit grabbableChanged();
}

QString PhysicalObjectParameter::toJSON() const
{
    QString json;
    json += "{\n";
    json += "    \"mass\": "             + QString::number(m_mass, 'f', 4)            + ",\n";
    json += "    \"bounceFactor\": "     + QString::number(m_bounceFactor, 'f', 4)    + ",\n";
    json += "    \"frictionStrength\": " + QString::number(m_frictionStrength, 'f', 4) + ",\n";
    json += "    \"linearDamping\": "    + QString::number(m_linearDamping, 'f', 4)   + ",\n";
    json += "    \"grabbable\": "        + QString(m_grabbable ? "true" : "false")    + "\n";
    json += "}";
    return json;
}

void PhysicalObjectParameter::applyJson(const QJsonObject &json)
{
    if (json.contains("mass"))             setMass(json["mass"].toDouble(m_mass));
    if (json.contains("bounceFactor"))     setBounceFactor(json["bounceFactor"].toDouble(m_bounceFactor));
    if (json.contains("frictionStrength")) setFrictionStrength(json["frictionStrength"].toDouble(m_frictionStrength));
    if (json.contains("linearDamping"))    setLinearDamping(json["linearDamping"].toDouble(m_linearDamping));
    if (json.contains("grabbable"))        setGrabbable(json["grabbable"].toBool(m_grabbable));
}
