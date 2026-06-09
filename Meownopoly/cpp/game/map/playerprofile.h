#ifndef PLAYERPROFILE_H
#define PLAYERPROFILE_H

#include <QObject>
#include <QString>
#include <QStringList>
#include <QJsonObject>

class PlayerProfile : public QObject
{
    Q_OBJECT

public:
    enum class PickMode : int {
        Unique    = 0,
        Shared    = 1,
        Mandatory = 2
    };
    Q_ENUM(PickMode)

private:
    Q_PROPERTY(QString  id              READ id              CONSTANT)
    Q_PROPERTY(QString  name            READ name            WRITE setName            NOTIFY nameChanged)
    Q_PROPERTY(QString  modelName       READ modelName       WRITE setModelName       NOTIFY modelNameChanged)
    // colorVariant : choix de re-skin du joueur, JSON sérialisé
    // { "skin": "...", "variant": "...", "teamColor": "#rrggbb" } ("" = défaut neutre).
    // Cf. doc/architecture/COLOR_ID_MAP_INTEGRATION_PLAN.md (Color ID Map).
    Q_PROPERTY(QString  colorVariant    READ colorVariant    WRITE setColorVariant    NOTIFY colorVariantChanged)
    Q_PROPERTY(PickMode pickMode        READ pickMode        WRITE setPickMode        NOTIFY pickModeChanged)
    Q_PROPERTY(int      minOccurrences  READ minOccurrences  WRITE setMinOccurrences  NOTIFY minOccurrencesChanged)

    Q_PROPERTY(qreal radius          READ radius          WRITE setRadius          NOTIFY radiusChanged)
    Q_PROPERTY(qreal mass            READ mass            WRITE setMass            NOTIFY massChanged)
    Q_PROPERTY(qreal acceleration    READ acceleration    WRITE setAcceleration    NOTIFY accelerationChanged)
    Q_PROPERTY(qreal maxSpeed        READ maxSpeed        WRITE setMaxSpeed        NOTIFY maxSpeedChanged)
    Q_PROPERTY(qreal linearDamping   READ linearDamping   WRITE setLinearDamping   NOTIFY linearDampingChanged)
    Q_PROPERTY(qreal staticFriction  READ staticFriction  WRITE setStaticFriction  NOTIFY staticFrictionChanged)
    Q_PROPERTY(qreal dynamicFriction READ dynamicFriction WRITE setDynamicFriction NOTIFY dynamicFrictionChanged)
    Q_PROPERTY(qreal bounceFactor    READ bounceFactor    WRITE setBounceFactor    NOTIFY bounceFactorChanged)

public:
    explicit PlayerProfile(QObject *parent = nullptr);
    explicit PlayerProfile(const QJsonObject &j, QObject *parent = nullptr);

    static constexpr int    MIN_OCCURRENCES_HARD_CAP = 8;

    static constexpr qreal  DEFAULT_RADIUS           = 0.4;
    static constexpr qreal  DEFAULT_MASS             = 1.0;
    static constexpr qreal  DEFAULT_ACCELERATION     = 30.0;
    static constexpr qreal  DEFAULT_MAX_SPEED        = 30.0;
    static constexpr qreal  DEFAULT_LINEAR_DAMPING   = 0.1;
    static constexpr qreal  DEFAULT_STATIC_FRICTION  = 0.4;
    static constexpr qreal  DEFAULT_DYNAMIC_FRICTION = 0.2;
    static constexpr qreal  DEFAULT_BOUNCE_FACTOR    = 0.1;

    QString  id() const              { return m_id; }
    QString  name() const            { return m_name; }
    QString  modelName() const       { return m_modelName; }
    QString  colorVariant() const    { return m_colorVariant; }
    PickMode pickMode() const        { return m_pickMode; }
    int      minOccurrences() const  { return m_minOccurrences; }
    qreal    radius() const          { return m_radius; }
    qreal    mass() const            { return m_mass; }
    qreal    acceleration() const    { return m_acceleration; }
    qreal    maxSpeed() const        { return m_maxSpeed; }
    qreal    linearDamping() const   { return m_linearDamping; }
    qreal    staticFriction() const  { return m_staticFriction; }
    qreal    dynamicFriction() const { return m_dynamicFriction; }
    qreal    bounceFactor() const    { return m_bounceFactor; }

    void setName(const QString &v);
    void setModelName(const QString &v);
    void setColorVariant(const QString &v);
    void setPickMode(PickMode v);
    void setMinOccurrences(int v);
    void setRadius(qreal v);
    void setMass(qreal v);
    void setAcceleration(qreal v);
    void setMaxSpeed(qreal v);
    void setLinearDamping(qreal v);
    void setStaticFriction(qreal v);
    void setDynamicFriction(qreal v);
    void setBounceFactor(qreal v);

    QJsonObject toJSON() const;
    void        applyJson(const QJsonObject &j);

    /// Sérialisation JSON pour QML (QJsonObject n'est pas convertible
    /// directement vers JS, mais une string l'est via JSON.parse).
    Q_INVOKABLE QString toJsonString() const;

    Q_INVOKABLE void        applyPreset(const QString &presetName);
    Q_INVOKABLE QStringList availablePresets() const;

    static QString pickModeToString(PickMode m);
    static PickMode pickModeFromString(const QString &s, PickMode fallback = PickMode::Unique);

    static void registerQml();

signals:
    void nameChanged();
    void modelNameChanged();
    void colorVariantChanged();
    void pickModeChanged();
    void minOccurrencesChanged();
    void radiusChanged();
    void massChanged();
    void accelerationChanged();
    void maxSpeedChanged();
    void linearDampingChanged();
    void staticFrictionChanged();
    void dynamicFrictionChanged();
    void bounceFactorChanged();

private:
    QString  m_id;
    QString  m_name           = QStringLiteral("Princess");
    QString  m_modelName      = QStringLiteral("Princess");
    QString  m_colorVariant;   // JSON re-skin, "" = défaut neutre
    PickMode m_pickMode       = PickMode::Unique;
    int      m_minOccurrences = 1;

    qreal m_radius          = DEFAULT_RADIUS;
    qreal m_mass            = DEFAULT_MASS;
    qreal m_acceleration    = DEFAULT_ACCELERATION;
    qreal m_maxSpeed        = DEFAULT_MAX_SPEED;
    qreal m_linearDamping   = DEFAULT_LINEAR_DAMPING;
    qreal m_staticFriction  = DEFAULT_STATIC_FRICTION;
    qreal m_dynamicFriction = DEFAULT_DYNAMIC_FRICTION;
    qreal m_bounceFactor    = DEFAULT_BOUNCE_FACTOR;
};

#endif // PLAYERPROFILE_H
