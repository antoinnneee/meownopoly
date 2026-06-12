#ifndef SCREENEFFECT_H
#define SCREENEFFECT_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>

/// Effet visuel plein écran déclenché quand le joueur entre dans une zone.
///
/// Un ScreenEffect est un *preset paramétrable* stocké dans la bibliothèque de
/// la carte (cf. MapInfo::screenEffects). Les zones (ZoneParameter) ne stockent
/// qu'une référence par id (screenEffectId), ce qui permet de mutualiser un
/// même effet sur plusieurs zones et de l'éditer en un seul endroit.
///
/// Le rendu est un overlay 2D (qml/world3d/ScreenEffectOverlay.qml) :
///   - teinte plein écran (tintColor à l'opacité `intensity`)
///   - vignette (concentration sur les bords, `vignette`)
///   - flou + désaturation de la scène 3D (`blur`, `saturation`) via MultiEffect
///   - pulsation optionnelle (`pulseSpeed`)
///   - fondu d'entrée / sortie (`fadeInMs` / `fadeOutMs`)
/// Le `type` sélectionne surtout une famille de presets / un style de motif ;
/// le rendu reste piloté par les paramètres ci-dessus.
class ScreenEffect : public QObject
{
    Q_OBJECT

public:
    enum class EffectType : int {
        Tint     = 0,   ///< Teinte plate
        Frost    = 1,   ///< Givré : cyan + flou + désaturation
        Toxic    = 2,   ///< Toxique : vert pulsant
        Heat     = 3,   ///< Chaleur : orange pulsant
        Vignette = 4,   ///< Vignette colorée (bords)
        Blur     = 5    ///< Flou seul
    };
    Q_ENUM(EffectType)

private:
    Q_PROPERTY(QString    id         READ id         CONSTANT)
    Q_PROPERTY(QString    name       READ name       WRITE setName       NOTIFY nameChanged)
    Q_PROPERTY(EffectType type       READ type       WRITE setType       NOTIFY typeChanged)
    Q_PROPERTY(QString    tintColor  READ tintColor  WRITE setTintColor  NOTIFY tintColorChanged)
    Q_PROPERTY(qreal      intensity  READ intensity  WRITE setIntensity  NOTIFY intensityChanged)
    Q_PROPERTY(qreal      vignette   READ vignette   WRITE setVignette   NOTIFY vignetteChanged)
    Q_PROPERTY(qreal      blur       READ blur       WRITE setBlur       NOTIFY blurChanged)
    Q_PROPERTY(qreal      saturation READ saturation WRITE setSaturation NOTIFY saturationChanged)
    Q_PROPERTY(qreal      pulseSpeed READ pulseSpeed WRITE setPulseSpeed NOTIFY pulseSpeedChanged)
    Q_PROPERTY(int        fadeInMs   READ fadeInMs   WRITE setFadeInMs   NOTIFY fadeInMsChanged)
    Q_PROPERTY(int        fadeOutMs  READ fadeOutMs  WRITE setFadeOutMs  NOTIFY fadeOutMsChanged)

public:
    explicit ScreenEffect(QObject *parent = nullptr);
    explicit ScreenEffect(const QJsonObject &j, QObject *parent = nullptr);

    static constexpr qreal DEFAULT_INTENSITY  = 0.4;
    static constexpr qreal DEFAULT_VIGNETTE   = 0.5;
    static constexpr qreal DEFAULT_BLUR       = 0.0;
    static constexpr qreal DEFAULT_SATURATION = 0.0;
    static constexpr qreal DEFAULT_PULSE      = 0.0;
    static constexpr int   DEFAULT_FADE_IN_MS  = 350;
    static constexpr int   DEFAULT_FADE_OUT_MS = 500;
    static constexpr int   FADE_MS_HARD_CAP    = 5000;

    QString    id() const         { return m_id; }
    QString    name() const       { return m_name; }
    EffectType type() const       { return m_type; }
    QString    tintColor() const  { return m_tintColor; }
    qreal      intensity() const  { return m_intensity; }
    qreal      vignette() const   { return m_vignette; }
    qreal      blur() const       { return m_blur; }
    qreal      saturation() const { return m_saturation; }
    qreal      pulseSpeed() const { return m_pulseSpeed; }
    int        fadeInMs() const   { return m_fadeInMs; }
    int        fadeOutMs() const  { return m_fadeOutMs; }

    void setName(const QString &v);
    void setType(EffectType v);
    void setTintColor(const QString &v);
    void setIntensity(qreal v);
    void setVignette(qreal v);
    void setBlur(qreal v);
    void setSaturation(qreal v);
    void setPulseSpeed(qreal v);
    void setFadeInMs(int v);
    void setFadeOutMs(int v);

    QJsonObject toJSON() const;
    void        applyJson(const QJsonObject &j);

    /// Sérialisation JSON pour QML (QJsonObject n'est pas convertible
    /// directement vers JS, mais une string l'est via JSON.parse).
    Q_INVOKABLE QString toJsonString() const;

    /// Applique un preset prédéfini (nom dans availablePresets). Met aussi à
    /// jour `type` ; ne touche pas à `id` ni à `name`.
    Q_INVOKABLE void        applyPreset(const QString &presetName);
    Q_INVOKABLE QStringList availablePresets() const;

    static QString    typeToString(EffectType t);
    static EffectType typeFromString(const QString &s, EffectType fallback = EffectType::Tint);

    static void registerQml();

signals:
    void nameChanged();
    void typeChanged();
    void tintColorChanged();
    void intensityChanged();
    void vignetteChanged();
    void blurChanged();
    void saturationChanged();
    void pulseSpeedChanged();
    void fadeInMsChanged();
    void fadeOutMsChanged();

private:
    QString    m_id;
    QString    m_name       = QStringLiteral("Effet");
    EffectType m_type       = EffectType::Tint;
    QString    m_tintColor  = QStringLiteral("#3366FF");
    qreal      m_intensity  = DEFAULT_INTENSITY;
    qreal      m_vignette   = DEFAULT_VIGNETTE;
    qreal      m_blur       = DEFAULT_BLUR;
    qreal      m_saturation = DEFAULT_SATURATION;
    qreal      m_pulseSpeed = DEFAULT_PULSE;
    int        m_fadeInMs   = DEFAULT_FADE_IN_MS;
    int        m_fadeOutMs  = DEFAULT_FADE_OUT_MS;
};

#endif // SCREENEFFECT_H
