#include "experience_module.h"

#include "level_module.h"

#include <QtMath>
#include <QDebug>

ExperienceModule::ExperienceModule(QObject *parent)
    : GameplayModule(QStringLiteral("experience"), QStringLiteral("Expérience"), parent)
{
}

int ExperienceModule::xpForLevel(int level) const
{
    // Courbe simple : round(100 * level^1.5). Croissance douce, documentée.
    return qRound(100.0 * qPow(static_cast<qreal>(qMax(1, level)), 1.5));
}

int ExperienceModule::xp(const QString &playerId) const
{
    return m_xp.value(playerId, 0);
}

int ExperienceModule::xpForNextLevel(const QString &playerId) const
{
    const int level = m_level ? m_level->level(playerId) : 1;
    return xpForLevel(level);
}

bool ExperienceModule::addXp(const QString &playerId, int amount)
{
    if (!effectiveEnabled()) {
        qWarning() << "[ExperienceModule] addXp ignoré — module désactivé";
        return false;
    }
    if (amount <= 0)
        return false;
    if (!m_level) {
        qWarning() << "[ExperienceModule] addXp : LevelModule non injecté";
        return false;
    }

    int total = m_xp.value(playerId, 0) + amount;

    // Multi-level-up avec carry-over : on consomme le seuil du niveau courant
    // tant qu'il est atteint et qu'on n'a pas plafonné.
    int level = m_level->level(playerId);
    while (level < m_level->maxLevel()) {
        const int need = xpForLevel(level);
        if (total < need)
            break;
        total -= need;                      // carry-over du surplus
        m_level->setLevel(playerId, level + 1);  // émet leveledUp
        ++level;
    }

    // Au niveau max : l'XP est clampée au seuil (barre pleine, plus de level-up).
    if (level >= m_level->maxLevel()) {
        const int cap = xpForLevel(level);
        if (total > cap)
            total = cap;
    }

    m_xp[playerId] = total;
    emit xpChanged(playerId, total, xpForNextLevel(playerId));
    return true;
}

void ExperienceModule::reset()
{
    m_xp.clear();
    GameplayModule::reset();
}
