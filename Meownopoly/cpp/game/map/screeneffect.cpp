#include "screeneffect.h"

#include <QJsonDocument>
#include <QQmlEngine>
#include <QUuid>

namespace {

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

ScreenEffect::ScreenEffect(QObject *parent)
    : QObject(parent)
    , m_id(newUuid())
{
}

ScreenEffect::ScreenEffect(const QJsonObject &j, QObject *parent)
    : QObject(parent)
{
    const QString jid = j.value(QStringLiteral("id")).toString();
    m_id = jid.isEmpty() ? newUuid() : jid;
    applyJson(j);
}

void ScreenEffect::setName(const QString &v)
{
    if (m_name == v) return;
    m_name = v;
    emit nameChanged();
}

void ScreenEffect::setType(EffectType v)
{
    if (m_type == v) return;
    m_type = v;
    emit typeChanged();
}

void ScreenEffect::setTintColor(const QString &v)
{
    if (m_tintColor == v) return;
    m_tintColor = v;
    emit tintColorChanged();
}

void ScreenEffect::setIntensity(qreal v)
{
    const qreal c = clampReal(v, 0.0, 1.0);
    if (qFuzzyCompare(m_intensity, c)) return;
    m_intensity = c;
    emit intensityChanged();
}

void ScreenEffect::setVignette(qreal v)
{
    const qreal c = clampReal(v, 0.0, 1.0);
    if (qFuzzyCompare(m_vignette, c)) return;
    m_vignette = c;
    emit vignetteChanged();
}

void ScreenEffect::setBlur(qreal v)
{
    const qreal c = clampReal(v, 0.0, 1.0);
    if (qFuzzyCompare(m_blur, c)) return;
    m_blur = c;
    emit blurChanged();
}

void ScreenEffect::setSaturation(qreal v)
{
    const qreal c = clampReal(v, -1.0, 1.0);
    if (qFuzzyCompare(m_saturation, c)) return;
    m_saturation = c;
    emit saturationChanged();
}

void ScreenEffect::setPulseSpeed(qreal v)
{
    const qreal c = clampReal(v, 0.0, 5.0);
    if (qFuzzyCompare(m_pulseSpeed, c)) return;
    m_pulseSpeed = c;
    emit pulseSpeedChanged();
}

void ScreenEffect::setFadeInMs(int v)
{
    const int c = clampInt(v, 0, FADE_MS_HARD_CAP);
    if (m_fadeInMs == c) return;
    m_fadeInMs = c;
    emit fadeInMsChanged();
}

void ScreenEffect::setFadeOutMs(int v)
{
    const int c = clampInt(v, 0, FADE_MS_HARD_CAP);
    if (m_fadeOutMs == c) return;
    m_fadeOutMs = c;
    emit fadeOutMsChanged();
}

QString ScreenEffect::typeToString(EffectType t)
{
    switch (t) {
    case EffectType::Tint:     return QStringLiteral("Tint");
    case EffectType::Frost:    return QStringLiteral("Frost");
    case EffectType::Toxic:    return QStringLiteral("Toxic");
    case EffectType::Heat:     return QStringLiteral("Heat");
    case EffectType::Vignette: return QStringLiteral("Vignette");
    case EffectType::Blur:     return QStringLiteral("Blur");
    }
    return QStringLiteral("Tint");
}

ScreenEffect::EffectType ScreenEffect::typeFromString(const QString &s, EffectType fallback)
{
    if (s.compare(QStringLiteral("Tint"),     Qt::CaseInsensitive) == 0) return EffectType::Tint;
    if (s.compare(QStringLiteral("Frost"),    Qt::CaseInsensitive) == 0) return EffectType::Frost;
    if (s.compare(QStringLiteral("Toxic"),    Qt::CaseInsensitive) == 0) return EffectType::Toxic;
    if (s.compare(QStringLiteral("Heat"),     Qt::CaseInsensitive) == 0) return EffectType::Heat;
    if (s.compare(QStringLiteral("Vignette"), Qt::CaseInsensitive) == 0) return EffectType::Vignette;
    if (s.compare(QStringLiteral("Blur"),     Qt::CaseInsensitive) == 0) return EffectType::Blur;
    return fallback;
}

QJsonObject ScreenEffect::toJSON() const
{
    QJsonObject j;
    j["id"]         = m_id;
    j["name"]       = m_name;
    j["type"]       = typeToString(m_type);
    j["tintColor"]  = m_tintColor;
    j["intensity"]  = m_intensity;
    j["vignette"]   = m_vignette;
    j["blur"]       = m_blur;
    j["saturation"] = m_saturation;
    j["pulseSpeed"] = m_pulseSpeed;
    j["fadeInMs"]   = m_fadeInMs;
    j["fadeOutMs"]  = m_fadeOutMs;
    return j;
}

QString ScreenEffect::toJsonString() const
{
    return QJsonDocument(toJSON()).toJson(QJsonDocument::Compact);
}

void ScreenEffect::applyJson(const QJsonObject &j)
{
    if (j.contains("name")) setName(j.value("name").toString(m_name));

    if (j.contains("type")) {
        const QJsonValue t = j.value("type");
        if (t.isString())      setType(typeFromString(t.toString(), m_type));
        else if (t.isDouble()) setType(static_cast<EffectType>(clampInt(t.toInt(), 0, 5)));
    }

    if (j.contains("tintColor"))  setTintColor(j.value("tintColor").toString(m_tintColor));
    if (j.contains("intensity"))  setIntensity(j.value("intensity").toDouble(m_intensity));
    if (j.contains("vignette"))   setVignette(j.value("vignette").toDouble(m_vignette));
    if (j.contains("blur"))       setBlur(j.value("blur").toDouble(m_blur));
    if (j.contains("saturation")) setSaturation(j.value("saturation").toDouble(m_saturation));
    if (j.contains("pulseSpeed")) setPulseSpeed(j.value("pulseSpeed").toDouble(m_pulseSpeed));
    if (j.contains("fadeInMs"))   setFadeInMs(j.value("fadeInMs").toInt(m_fadeInMs));
    if (j.contains("fadeOutMs"))  setFadeOutMs(j.value("fadeOutMs").toInt(m_fadeOutMs));
}

QStringList ScreenEffect::availablePresets() const
{
    return {
        QStringLiteral("Givré"),
        QStringLiteral("Toxique"),
        QStringLiteral("Chaleur"),
        QStringLiteral("Ténèbres"),
        QStringLiteral("Flou"),
        QStringLiteral("Teinte")
    };
}

void ScreenEffect::applyPreset(const QString &presetName)
{
    if (presetName.compare(QStringLiteral("Givré"), Qt::CaseInsensitive) == 0) {
        setType(EffectType::Frost);
        setTintColor(QStringLiteral("#BFE9FF"));
        setIntensity(0.55);
        setVignette(0.55);
        setBlur(0.35);
        setSaturation(-0.4);
        setPulseSpeed(0.0);
    } else if (presetName.compare(QStringLiteral("Toxique"), Qt::CaseInsensitive) == 0) {
        setType(EffectType::Toxic);
        setTintColor(QStringLiteral("#6BFF6B"));
        setIntensity(0.45);
        setVignette(0.6);
        setBlur(0.1);
        setSaturation(-0.1);
        setPulseSpeed(1.2);
    } else if (presetName.compare(QStringLiteral("Chaleur"), Qt::CaseInsensitive) == 0) {
        setType(EffectType::Heat);
        setTintColor(QStringLiteral("#FF7A2A"));
        setIntensity(0.4);
        setVignette(0.65);
        setBlur(0.05);
        setSaturation(0.2);
        setPulseSpeed(0.8);
    } else if (presetName.compare(QStringLiteral("Ténèbres"), Qt::CaseInsensitive) == 0) {
        setType(EffectType::Vignette);
        setTintColor(QStringLiteral("#000000"));
        setIntensity(0.7);
        setVignette(0.85);
        setBlur(0.0);
        setSaturation(-0.2);
        setPulseSpeed(0.0);
    } else if (presetName.compare(QStringLiteral("Flou"), Qt::CaseInsensitive) == 0) {
        setType(EffectType::Blur);
        setTintColor(QStringLiteral("#FFFFFF"));
        setIntensity(0.0);
        setVignette(0.0);
        setBlur(0.6);
        setSaturation(0.0);
        setPulseSpeed(0.0);
    } else if (presetName.compare(QStringLiteral("Teinte"), Qt::CaseInsensitive) == 0) {
        setType(EffectType::Tint);
        setTintColor(QStringLiteral("#3366FF"));
        setIntensity(0.3);
        setVignette(0.0);
        setBlur(0.0);
        setSaturation(0.0);
        setPulseSpeed(0.0);
    }
}

void ScreenEffect::registerQml()
{
    qmlRegisterType<ScreenEffect>("ScreenEffect", 1, 0, "ScreenEffect");
    qmlRegisterUncreatableType<ScreenEffect>(
        "ScreenEffect", 1, 0, "EffectType",
        QStringLiteral("EffectType is an enum, use ScreenEffect.Tint/Frost/Toxic/Heat/Vignette/Blur"));
}
