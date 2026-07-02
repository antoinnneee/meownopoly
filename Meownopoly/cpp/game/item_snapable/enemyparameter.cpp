#include "enemyparameter.h"

#include <QJsonDocument>
#include <QDebug>

EnemyParameter::EnemyParameter(QObject *parent)
    : QObject(parent)
{
}

EnemyParameter::EnemyParameter(const QJsonObject &json, QObject *parent)
    : QObject(parent)
{
    // Le ctor JSON ne passe pas par applyJson (pas d'émission de signaux
    // pendant la construction) mais lit les mêmes clés.
    const int version = json.value("enemyVersion").toInt(k_currentEnemyVersion);
    if (version > k_currentEnemyVersion) {
        qWarning() << "ENEMY_PARAMETER: enemyVersion" << version
                   << "> version courante" << k_currentEnemyVersion
                   << "- paramètres réinitialisés aux défauts";
        return;
    }
    m_enemyName = json.value("enemyName").toString("");
    m_modelName = json.value("modelName").toString("");
    m_maxHp = qMax(1, json.value("maxHp").toInt(30));
    m_attackDamage = qMax(0, json.value("attackDamage").toInt(5));
    m_attackRange = qMax(0.1, json.value("attackRange").toDouble(1.2));
    m_attackCooldownMs = qMax(100, json.value("attackCooldownMs").toInt(1000));
    m_aggroRange = qMax(0.0, json.value("aggroRange").toDouble(4.0));
    m_moveSpeed = qMax(0.0, json.value("moveSpeed").toDouble(2.0));
    m_respawnEnabled = json.value("respawnEnabled").toBool(false);
    m_respawnDelayMs = qMax(500, json.value("respawnDelayMs").toInt(5000));
    m_lootCurrency = qMax(0, json.value("lootCurrency").toInt(0));
    m_lootItemName = json.value("lootItemName").toString("");
    m_lootItemQuantity = qMax(1, json.value("lootItemQuantity").toInt(1));
}

QJsonObject EnemyParameter::toJsonObject() const
{
    return QJsonObject{
        { "enemyVersion",     k_currentEnemyVersion },
        { "enemyName",        m_enemyName },
        { "modelName",        m_modelName },
        { "maxHp",            m_maxHp },
        { "attackDamage",     m_attackDamage },
        { "attackRange",      m_attackRange },
        { "attackCooldownMs", m_attackCooldownMs },
        { "aggroRange",       m_aggroRange },
        { "moveSpeed",        m_moveSpeed },
        { "respawnEnabled",   m_respawnEnabled },
        { "respawnDelayMs",   m_respawnDelayMs },
        { "lootCurrency",     m_lootCurrency },
        { "lootItemName",     m_lootItemName },
        { "lootItemQuantity", m_lootItemQuantity },
    };
}

QString EnemyParameter::toJSON()
{
    // Sérialisation via QJsonDocument : enemyName est du texte libre,
    // l'échappement manuel des autres toJSON() du projet casserait ici.
    return QString::fromUtf8(
        QJsonDocument(toJsonObject()).toJson(QJsonDocument::Compact));
}

void EnemyParameter::applyJson(const QJsonObject &json)
{
    const int version = json.value("enemyVersion").toInt(k_currentEnemyVersion);
    if (version > k_currentEnemyVersion) {
        qWarning() << "ENEMY_PARAMETER: applyJson enemyVersion" << version
                   << "> version courante" << k_currentEnemyVersion << "- ignoré";
        return;
    }
    setEnemyName(json.value("enemyName").toString(""));
    setModelName(json.value("modelName").toString(""));
    setMaxHp(json.value("maxHp").toInt(30));
    setAttackDamage(json.value("attackDamage").toInt(5));
    setAttackRange(json.value("attackRange").toDouble(1.2));
    setAttackCooldownMs(json.value("attackCooldownMs").toInt(1000));
    setAggroRange(json.value("aggroRange").toDouble(4.0));
    setMoveSpeed(json.value("moveSpeed").toDouble(2.0));
    setRespawnEnabled(json.value("respawnEnabled").toBool(false));
    setRespawnDelayMs(json.value("respawnDelayMs").toInt(5000));
    setLootCurrency(json.value("lootCurrency").toInt(0));
    setLootItemName(json.value("lootItemName").toString(""));
    setLootItemQuantity(json.value("lootItemQuantity").toInt(1));
}

QString EnemyParameter::enemyName() const
{
    return m_enemyName;
}

void EnemyParameter::setEnemyName(const QString &name)
{
    if (m_enemyName == name)
        return;
    m_enemyName = name;
    emit enemyNameChanged();
}

QString EnemyParameter::modelName() const
{
    return m_modelName;
}

void EnemyParameter::setModelName(const QString &name)
{
    if (m_modelName == name)
        return;
    m_modelName = name;
    emit modelNameChanged();
}

int EnemyParameter::maxHp() const
{
    return m_maxHp;
}

void EnemyParameter::setMaxHp(int hp)
{
    hp = qMax(1, hp);
    if (m_maxHp == hp)
        return;
    m_maxHp = hp;
    emit maxHpChanged();
}

int EnemyParameter::attackDamage() const
{
    return m_attackDamage;
}

void EnemyParameter::setAttackDamage(int damage)
{
    damage = qMax(0, damage);
    if (m_attackDamage == damage)
        return;
    m_attackDamage = damage;
    emit attackDamageChanged();
}

qreal EnemyParameter::attackRange() const
{
    return m_attackRange;
}

void EnemyParameter::setAttackRange(qreal range)
{
    range = qMax(0.1, range);
    if (qFuzzyCompare(m_attackRange, range))
        return;
    m_attackRange = range;
    emit attackRangeChanged();
}

int EnemyParameter::attackCooldownMs() const
{
    return m_attackCooldownMs;
}

void EnemyParameter::setAttackCooldownMs(int ms)
{
    ms = qMax(100, ms);
    if (m_attackCooldownMs == ms)
        return;
    m_attackCooldownMs = ms;
    emit attackCooldownMsChanged();
}

qreal EnemyParameter::aggroRange() const
{
    return m_aggroRange;
}

void EnemyParameter::setAggroRange(qreal range)
{
    range = qMax(0.0, range);
    if (qFuzzyCompare(m_aggroRange, range))
        return;
    m_aggroRange = range;
    emit aggroRangeChanged();
}

qreal EnemyParameter::moveSpeed() const
{
    return m_moveSpeed;
}

void EnemyParameter::setMoveSpeed(qreal speed)
{
    speed = qMax(0.0, speed);
    if (qFuzzyCompare(m_moveSpeed, speed))
        return;
    m_moveSpeed = speed;
    emit moveSpeedChanged();
}

bool EnemyParameter::respawnEnabled() const
{
    return m_respawnEnabled;
}

void EnemyParameter::setRespawnEnabled(bool enabled)
{
    if (m_respawnEnabled == enabled)
        return;
    m_respawnEnabled = enabled;
    emit respawnEnabledChanged();
}

int EnemyParameter::lootCurrency() const
{
    return m_lootCurrency;
}

void EnemyParameter::setLootCurrency(int amount)
{
    amount = qMax(0, amount);
    if (m_lootCurrency == amount)
        return;
    m_lootCurrency = amount;
    emit lootCurrencyChanged();
}

QString EnemyParameter::lootItemName() const
{
    return m_lootItemName;
}

void EnemyParameter::setLootItemName(const QString &name)
{
    if (m_lootItemName == name)
        return;
    m_lootItemName = name;
    emit lootItemNameChanged();
}

int EnemyParameter::lootItemQuantity() const
{
    return m_lootItemQuantity;
}

void EnemyParameter::setLootItemQuantity(int quantity)
{
    quantity = qMax(1, quantity);
    if (m_lootItemQuantity == quantity)
        return;
    m_lootItemQuantity = quantity;
    emit lootItemQuantityChanged();
}

int EnemyParameter::respawnDelayMs() const
{
    return m_respawnDelayMs;
}

void EnemyParameter::setRespawnDelayMs(int ms)
{
    ms = qMax(500, ms);
    if (m_respawnDelayMs == ms)
        return;
    m_respawnDelayMs = ms;
    emit respawnDelayMsChanged();
}
