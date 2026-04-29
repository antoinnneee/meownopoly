#include "playerprofile.h"

#include <QJsonDocument>
#include <QQmlEngine>
#include <QUuid>
#include <QtMath>

namespace {

constexpr qreal RADIUS_MIN = 0.1;
constexpr qreal RADIUS_MAX = 1.5;
constexpr qreal MASS_MIN   = 0.1;
constexpr qreal MASS_MAX   = 10.0;
constexpr qreal MAX_SPEED_MIN  = 50.0;
constexpr qreal MAX_SPEED_MAX  = 800.0;
constexpr qreal ACCELERATION_MIN = 5.0;
constexpr qreal ACCELERATION_MAX = 100.0;
constexpr qreal LINEAR_DAMPING_MIN = 0.0;
constexpr qreal LINEAR_DAMPING_MAX = 1.0;
constexpr qreal STATIC_FRICTION_MIN = 0.0;
constexpr qreal STATIC_FRICTION_MAX = 2.0;
constexpr qreal DYNAMIC_FRICTION_MIN = 0.0;
constexpr qreal DYNAMIC_FRICTION_MAX = 2.0;
constexpr qreal BOUNCE_FACTOR_MIN = 0.0;
constexpr qreal BOUNCE_FACTOR_MAX = 1.0;

inline qreal clampReal(qreal v, qreal lo, qreal hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

inline int clampInt(int v, int lo, int hi)
{
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

QString newUuid()
{
    return QUuid::createUuid().toString(QUuid::WithoutBraces);
}

} // namespace

PlayerProfile::PlayerProfile(QObject *parent)
    : QObject(parent)
    , m_id(newUuid())
{
}

PlayerProfile::PlayerProfile(const QJsonObject &j, QObject *parent)
    : QObject(parent)
{
    const QString jid = j.value(QStringLiteral("id")).toString();
    m_id = jid.isEmpty() ? newUuid() : jid;
    applyJson(j);
}

void PlayerProfile::setName(const QString &v)
{
    if (m_name == v) return;
    m_name = v;
    emit nameChanged();
}

void PlayerProfile::setModelName(const QString &v)
{
    if (m_modelName == v) return;
    m_modelName = v;
    emit modelNameChanged();
}

void PlayerProfile::setPickMode(PickMode v)
{
    if (m_pickMode == v) return;
    m_pickMode = v;
    if (m_pickMode == PickMode::Mandatory && m_minOccurrences < 1) {
        m_minOccurrences = 1;
        emit minOccurrencesChanged();
    }
    emit pickModeChanged();
}

void PlayerProfile::setMinOccurrences(int v)
{
    const int clamped = clampInt(v, 1, MIN_OCCURRENCES_HARD_CAP);
    if (m_minOccurrences == clamped) return;
    m_minOccurrences = clamped;
    emit minOccurrencesChanged();
}

void PlayerProfile::setRadius(qreal v)
{
    const qreal c = clampReal(v, RADIUS_MIN, RADIUS_MAX);
    if (qFuzzyCompare(m_radius, c)) return;
    m_radius = c;
    emit radiusChanged();
}

void PlayerProfile::setMass(qreal v)
{
    const qreal c = clampReal(v, MASS_MIN, MASS_MAX);
    if (qFuzzyCompare(m_mass, c)) return;
    m_mass = c;
    emit massChanged();
}

void PlayerProfile::setAcceleration(qreal v)
{
    const qreal c = clampReal(v, ACCELERATION_MIN, ACCELERATION_MAX);
    if (qFuzzyCompare(m_acceleration, c)) return;
    m_acceleration = c;
    emit accelerationChanged();
}

void PlayerProfile::setMaxSpeed(qreal v)
{
    const qreal c = clampReal(v, MAX_SPEED_MIN, MAX_SPEED_MAX);
    if (qFuzzyCompare(m_maxSpeed, c)) return;
    m_maxSpeed = c;
    emit maxSpeedChanged();
}

void PlayerProfile::setLinearDamping(qreal v)
{
    const qreal c = clampReal(v, LINEAR_DAMPING_MIN, LINEAR_DAMPING_MAX);
    if (qFuzzyCompare(m_linearDamping, c)) return;
    m_linearDamping = c;
    emit linearDampingChanged();
}

void PlayerProfile::setStaticFriction(qreal v)
{
    const qreal c = clampReal(v, STATIC_FRICTION_MIN, STATIC_FRICTION_MAX);
    if (qFuzzyCompare(m_staticFriction, c)) return;
    m_staticFriction = c;
    emit staticFrictionChanged();
}

void PlayerProfile::setDynamicFriction(qreal v)
{
    const qreal c = clampReal(v, DYNAMIC_FRICTION_MIN, DYNAMIC_FRICTION_MAX);
    if (qFuzzyCompare(m_dynamicFriction, c)) return;
    m_dynamicFriction = c;
    emit dynamicFrictionChanged();
}

void PlayerProfile::setBounceFactor(qreal v)
{
    const qreal c = clampReal(v, BOUNCE_FACTOR_MIN, BOUNCE_FACTOR_MAX);
    if (qFuzzyCompare(m_bounceFactor, c)) return;
    m_bounceFactor = c;
    emit bounceFactorChanged();
}

QString PlayerProfile::pickModeToString(PickMode m)
{
    switch (m) {
    case PickMode::Unique:    return QStringLiteral("Unique");
    case PickMode::Shared:    return QStringLiteral("Shared");
    case PickMode::Mandatory: return QStringLiteral("Mandatory");
    }
    return QStringLiteral("Unique");
}

PlayerProfile::PickMode PlayerProfile::pickModeFromString(const QString &s, PickMode fallback)
{
    if (s.compare(QStringLiteral("Unique"), Qt::CaseInsensitive) == 0)    return PickMode::Unique;
    if (s.compare(QStringLiteral("Shared"), Qt::CaseInsensitive) == 0)    return PickMode::Shared;
    if (s.compare(QStringLiteral("Mandatory"), Qt::CaseInsensitive) == 0) return PickMode::Mandatory;
    return fallback;
}

QJsonObject PlayerProfile::toJSON() const
{
    QJsonObject j;
    j["id"]              = m_id;
    j["name"]            = m_name;
    j["modelName"]       = m_modelName;
    j["pickMode"]        = pickModeToString(m_pickMode);
    j["minOccurrences"]  = m_minOccurrences;
    j["radius"]          = m_radius;
    j["mass"]            = m_mass;
    j["acceleration"]    = m_acceleration;
    j["maxSpeed"]        = m_maxSpeed;
    j["linearDamping"]   = m_linearDamping;
    j["staticFriction"]  = m_staticFriction;
    j["dynamicFriction"] = m_dynamicFriction;
    j["bounceFactor"]    = m_bounceFactor;
    return j;
}

QString PlayerProfile::toJsonString() const
{
    return QJsonDocument(toJSON()).toJson(QJsonDocument::Compact);
}

void PlayerProfile::applyJson(const QJsonObject &j)
{
    if (j.contains("name"))            setName(j.value("name").toString(m_name));
    if (j.contains("modelName"))       setModelName(j.value("modelName").toString(m_modelName));

    if (j.contains("pickMode")) {
        const QJsonValue pm = j.value("pickMode");
        if (pm.isString())      setPickMode(pickModeFromString(pm.toString(), m_pickMode));
        else if (pm.isDouble()) setPickMode(static_cast<PickMode>(clampInt(pm.toInt(), 0, 2)));
    }
    if (j.contains("minOccurrences")) setMinOccurrences(j.value("minOccurrences").toInt(m_minOccurrences));

    if (j.contains("radius"))          setRadius(j.value("radius").toDouble(m_radius));
    if (j.contains("mass"))            setMass(j.value("mass").toDouble(m_mass));
    if (j.contains("acceleration"))    setAcceleration(j.value("acceleration").toDouble(m_acceleration));
    if (j.contains("maxSpeed"))        setMaxSpeed(j.value("maxSpeed").toDouble(m_maxSpeed));
    if (j.contains("linearDamping"))   setLinearDamping(j.value("linearDamping").toDouble(m_linearDamping));
    if (j.contains("staticFriction"))  setStaticFriction(j.value("staticFriction").toDouble(m_staticFriction));
    if (j.contains("dynamicFriction")) setDynamicFriction(j.value("dynamicFriction").toDouble(m_dynamicFriction));
    if (j.contains("bounceFactor"))    setBounceFactor(j.value("bounceFactor").toDouble(m_bounceFactor));
}

QStringList PlayerProfile::availablePresets() const
{
    return {
        QStringLiteral("Standard"),
        QStringLiteral("Léger"),
        QStringLiteral("Lourd"),
        QStringLiteral("Glissant"),
        QStringLiteral("Adhérent")
    };
}

void PlayerProfile::applyPreset(const QString &presetName)
{
    // Les presets ne touchent pas pickMode / minOccurrences / name / modelName.
    if (presetName.compare(QStringLiteral("Standard"), Qt::CaseInsensitive) == 0) {
        setRadius(DEFAULT_RADIUS);
        setMass(DEFAULT_MASS);
        setAcceleration(DEFAULT_ACCELERATION);
        setMaxSpeed(DEFAULT_MAX_SPEED);
        setLinearDamping(DEFAULT_LINEAR_DAMPING);
        setStaticFriction(DEFAULT_STATIC_FRICTION);
        setDynamicFriction(DEFAULT_DYNAMIC_FRICTION);
        setBounceFactor(DEFAULT_BOUNCE_FACTOR);
    } else if (presetName.compare(QStringLiteral("Léger"), Qt::CaseInsensitive) == 0) {
        setRadius(0.3);
        setMass(0.5);
        setAcceleration(50.0);
        setMaxSpeed(70.0);
        setLinearDamping(0.05);
        setStaticFriction(DEFAULT_STATIC_FRICTION);
        setDynamicFriction(DEFAULT_DYNAMIC_FRICTION);
        setBounceFactor(DEFAULT_BOUNCE_FACTOR);
    } else if (presetName.compare(QStringLiteral("Lourd"), Qt::CaseInsensitive) == 0) {
        setRadius(0.55);
        setMass(3.0);
        setAcceleration(15.0);
        setMaxSpeed(20.0);
        setLinearDamping(0.2);
        setStaticFriction(DEFAULT_STATIC_FRICTION);
        setDynamicFriction(DEFAULT_DYNAMIC_FRICTION);
        setBounceFactor(DEFAULT_BOUNCE_FACTOR);
    } else if (presetName.compare(QStringLiteral("Glissant"), Qt::CaseInsensitive) == 0) {
        setRadius(DEFAULT_RADIUS);
        setMass(DEFAULT_MASS);
        setAcceleration(DEFAULT_ACCELERATION);
        setMaxSpeed(DEFAULT_MAX_SPEED);
        setLinearDamping(0.0);
        setStaticFriction(0.1);
        setDynamicFriction(0.05);
        setBounceFactor(0.5);
    } else if (presetName.compare(QStringLiteral("Adhérent"), Qt::CaseInsensitive) == 0) {
        setRadius(DEFAULT_RADIUS);
        setMass(DEFAULT_MASS);
        setAcceleration(DEFAULT_ACCELERATION);
        setMaxSpeed(DEFAULT_MAX_SPEED);
        setLinearDamping(0.5);
        setStaticFriction(1.5);
        setDynamicFriction(1.0);
        setBounceFactor(0.0);
    }
}

void PlayerProfile::registerQml()
{
    qmlRegisterType<PlayerProfile>("PlayerProfile", 1, 0, "PlayerProfile");
    qmlRegisterUncreatableType<PlayerProfile>(
        "PlayerProfile", 1, 0, "PickMode",
        QStringLiteral("PickMode is an enum, use PlayerProfile.Unique/Shared/Mandatory"));
}
