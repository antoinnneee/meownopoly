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

void PhysicalObjectParameter::setMass(qreal v)
{
    if (qFuzzyCompare(m_mass, v)) return;
    m_mass = v;
    emit massChanged();
}

void PhysicalObjectParameter::setBounceFactor(qreal v)
{
    if (qFuzzyCompare(m_bounceFactor, v)) return;
    m_bounceFactor = v;
    emit bounceFactorChanged();
}

void PhysicalObjectParameter::setFrictionStrength(qreal v)
{
    if (qFuzzyCompare(m_frictionStrength, v)) return;
    m_frictionStrength = v;
    emit frictionStrengthChanged();
}

void PhysicalObjectParameter::setLinearDamping(qreal v)
{
    if (qFuzzyCompare(m_linearDamping, v)) return;
    m_linearDamping = v;
    emit linearDampingChanged();
}

QString PhysicalObjectParameter::toJSON() const
{
    QString json;
    json += "{\n";
    json += "    \"mass\": "             + QString::number(m_mass, 'f', 4)            + ",\n";
    json += "    \"bounceFactor\": "     + QString::number(m_bounceFactor, 'f', 4)    + ",\n";
    json += "    \"frictionStrength\": " + QString::number(m_frictionStrength, 'f', 4) + ",\n";
    json += "    \"linearDamping\": "    + QString::number(m_linearDamping, 'f', 4)   + "\n";
    json += "}";
    return json;
}

void PhysicalObjectParameter::applyJson(const QJsonObject &json)
{
    if (json.contains("mass"))             setMass(json["mass"].toDouble(m_mass));
    if (json.contains("bounceFactor"))     setBounceFactor(json["bounceFactor"].toDouble(m_bounceFactor));
    if (json.contains("frictionStrength")) setFrictionStrength(json["frictionStrength"].toDouble(m_frictionStrength));
    if (json.contains("linearDamping"))    setLinearDamping(json["linearDamping"].toDouble(m_linearDamping));
}
