#include "health_module.h"

#include <QDebug>

HealthModule::HealthModule(QObject *parent)
    : GameplayModule(QStringLiteral("health"), QStringLiteral("Module de vie"), parent)
{
}

void HealthModule::setDefaultMaxHp(int maxHp)
{
    maxHp = qMax(1, maxHp);
    if (m_defaultMaxHp == maxHp)
        return;
    m_defaultMaxHp = maxHp;
    emit defaultMaxHpChanged();
}

HealthModule::HealthState &HealthModule::stateFor(const QString &playerId)
{
    auto it = m_states.find(playerId);
    if (it == m_states.end()) {
        HealthState st;
        st.maxHp = m_defaultMaxHp;
        st.hp = m_defaultMaxHp;
        it = m_states.insert(playerId, st);
    }
    return it.value();
}

int HealthModule::hp(const QString &playerId)
{
    return stateFor(playerId).hp;
}

int HealthModule::maxHp(const QString &playerId)
{
    return stateFor(playerId).maxHp;
}

bool HealthModule::isDead(const QString &playerId)
{
    return stateFor(playerId).hp <= 0;
}

bool HealthModule::hasPlayer(const QString &playerId) const
{
    return m_states.contains(playerId);
}

bool HealthModule::registerPlayer(const QString &playerId, int maxHp)
{
    if (!enabled()) {
        qWarning() << "[HealthModule] registerPlayer ignoré — module désactivé";
        return false;
    }
    HealthState &st = stateFor(playerId);
    st.maxHp = (maxHp > 0) ? maxHp : m_defaultMaxHp;
    st.hp = st.maxHp;
    emit healthChanged(playerId, st.hp, st.maxHp);
    return true;
}

bool HealthModule::damage(const QString &playerId, int amount)
{
    if (!enabled()) {
        qWarning() << "[HealthModule] damage ignoré — module désactivé";
        return false;
    }
    if (amount <= 0)
        return false;
    HealthState &st = stateFor(playerId);
    const bool wasDead = st.hp <= 0;
    st.hp = qMax(0, st.hp - amount);
    emit healthChanged(playerId, st.hp, st.maxHp);
    if (!wasDead && st.hp <= 0)
        emit playerDied(playerId);
    return true;
}

bool HealthModule::heal(const QString &playerId, int amount)
{
    if (!enabled()) {
        qWarning() << "[HealthModule] heal ignoré — module désactivé";
        return false;
    }
    if (amount <= 0)
        return false;
    HealthState &st = stateFor(playerId);
    const bool wasDead = st.hp <= 0;
    st.hp = qMin(st.maxHp, st.hp + amount);
    emit healthChanged(playerId, st.hp, st.maxHp);
    if (wasDead && st.hp > 0)
        emit playerRevived(playerId);
    return true;
}

bool HealthModule::setHp(const QString &playerId, int hp)
{
    if (!enabled()) {
        qWarning() << "[HealthModule] setHp ignoré — module désactivé";
        return false;
    }
    HealthState &st = stateFor(playerId);
    const bool wasDead = st.hp <= 0;
    st.hp = qBound(0, hp, st.maxHp);
    emit healthChanged(playerId, st.hp, st.maxHp);
    if (!wasDead && st.hp <= 0)
        emit playerDied(playerId);
    else if (wasDead && st.hp > 0)
        emit playerRevived(playerId);
    return true;
}

bool HealthModule::setMaxHp(const QString &playerId, int maxHp)
{
    // NON gatée par enabled() : surface d'intégration pilotée par la stat
    // effective maxHealth (cf. sémantique de l'API de modificateurs de
    // StatsModule). maxHp < 1 est interdit → clamp à 1 minimum.
    maxHp = qMax(1, maxHp);
    HealthState &st = stateFor(playerId);
    const bool wasDead = st.hp <= 0;
    st.maxHp = maxHp;
    // Clamp des PV courants au nouveau max (si le max augmente, hp inchangé —
    // pas de soin gratuit).
    if (st.hp > st.maxHp)
        st.hp = st.maxHp;
    emit healthChanged(playerId, st.hp, st.maxHp);
    // Le clamp ne peut pas tuer un joueur vivant (maxHp >= 1 garanti), mais on
    // couvre le cas par cohérence avec le reste de l'API.
    if (!wasDead && st.hp <= 0)
        emit playerDied(playerId);
    return true;
}

bool HealthModule::revive(const QString &playerId)
{
    if (!enabled()) {
        qWarning() << "[HealthModule] revive ignoré — module désactivé";
        return false;
    }
    HealthState &st = stateFor(playerId);
    const bool wasDead = st.hp <= 0;
    st.hp = st.maxHp;
    emit healthChanged(playerId, st.hp, st.maxHp);
    if (wasDead)
        emit playerRevived(playerId);
    return true;
}

void HealthModule::reset()
{
    m_states.clear();
}
