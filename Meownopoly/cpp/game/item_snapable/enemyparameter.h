#ifndef ENEMYPARAMETER_H
#define ENEMYPARAMETER_H

#include <QObject>
#include <QJsonObject>

/// Paramètres d'un ennemi porté par un ItemSnapable de type EnemyTile :
/// identité (nom + modèle 3D) et statistiques de combat (PV, dégâts, portées,
/// vitesse, respawn). Calqué sur NPCParameter : Q_PROPERTY + ctor JSON +
/// applyJson + operator==, sérialisation via QJsonObject/QJsonDocument.
class EnemyParameter : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString enemyName READ enemyName WRITE setEnemyName NOTIFY enemyNameChanged FINAL)
    Q_PROPERTY(QString modelName READ modelName WRITE setModelName NOTIFY modelNameChanged FINAL)
    Q_PROPERTY(int maxHp READ maxHp WRITE setMaxHp NOTIFY maxHpChanged FINAL)
    Q_PROPERTY(int attackDamage READ attackDamage WRITE setAttackDamage NOTIFY attackDamageChanged FINAL)
    Q_PROPERTY(qreal attackRange READ attackRange WRITE setAttackRange NOTIFY attackRangeChanged FINAL)
    Q_PROPERTY(int attackCooldownMs READ attackCooldownMs WRITE setAttackCooldownMs NOTIFY attackCooldownMsChanged FINAL)
    Q_PROPERTY(qreal aggroRange READ aggroRange WRITE setAggroRange NOTIFY aggroRangeChanged FINAL)
    Q_PROPERTY(qreal moveSpeed READ moveSpeed WRITE setMoveSpeed NOTIFY moveSpeedChanged FINAL)
    Q_PROPERTY(bool respawnEnabled READ respawnEnabled WRITE setRespawnEnabled NOTIFY respawnEnabledChanged FINAL)
    Q_PROPERTY(int respawnDelayMs READ respawnDelayMs WRITE setRespawnDelayMs NOTIFY respawnDelayMsChanged FINAL)

public:
    /// Version courante du schéma de sérialisation (analogue à npcVersion) :
    /// version > courante → reset aux défauts + warning.
    static constexpr int k_currentEnemyVersion = 1;

    explicit EnemyParameter(QObject *parent = nullptr);
    explicit EnemyParameter(const QJsonObject &json, QObject *parent = nullptr);

    bool operator==(const EnemyParameter &other) const {
        return m_enemyName        == other.m_enemyName
            && m_modelName        == other.m_modelName
            && m_maxHp            == other.m_maxHp
            && m_attackDamage     == other.m_attackDamage
            && qFuzzyCompare(m_attackRange, other.m_attackRange)
            && m_attackCooldownMs == other.m_attackCooldownMs
            && qFuzzyCompare(m_aggroRange, other.m_aggroRange)
            && qFuzzyCompare(m_moveSpeed, other.m_moveSpeed)
            && m_respawnEnabled   == other.m_respawnEnabled
            && m_respawnDelayMs   == other.m_respawnDelayMs;
    }

    Q_INVOKABLE QString toJSON();
    QJsonObject toJsonObject() const;
    /// Q_INVOKABLE : le remote-apply QML (op SetEnemyParameter) passe le
    /// payload `fields` directement (JS object → QJsonObject).
    Q_INVOKABLE void applyJson(const QJsonObject &json);

    QString enemyName() const;
    void setEnemyName(const QString &name);

    QString modelName() const;
    void setModelName(const QString &name);

    int maxHp() const;
    void setMaxHp(int hp);

    int attackDamage() const;
    void setAttackDamage(int damage);

    qreal attackRange() const;
    void setAttackRange(qreal range);

    int attackCooldownMs() const;
    void setAttackCooldownMs(int ms);

    qreal aggroRange() const;
    void setAggroRange(qreal range);

    qreal moveSpeed() const;
    void setMoveSpeed(qreal speed);

    bool respawnEnabled() const;
    void setRespawnEnabled(bool enabled);

    int respawnDelayMs() const;
    void setRespawnDelayMs(int ms);

signals:
    void enemyNameChanged();
    void modelNameChanged();
    void maxHpChanged();
    void attackDamageChanged();
    void attackRangeChanged();
    void attackCooldownMsChanged();
    void aggroRangeChanged();
    void moveSpeedChanged();
    void respawnEnabledChanged();
    void respawnDelayMsChanged();

private:
    QString m_enemyName;
    QString m_modelName;
    int m_maxHp = 30;
    int m_attackDamage = 5;
    qreal m_attackRange = 1.2;
    int m_attackCooldownMs = 1000;
    qreal m_aggroRange = 4.0;
    qreal m_moveSpeed = 2.0;
    bool m_respawnEnabled = false;
    int m_respawnDelayMs = 5000;
};

#endif // ENEMYPARAMETER_H
