#include "level_module.h"

#include "experience_module.h"

#include <QDebug>

LevelModule::LevelModule(QObject *parent)
    : GameplayModule(QStringLiteral("level"), QStringLiteral("Niveau"), parent)
{
    // Crée et enregistre le sous-module d'expérience (ownership pris par
    // registerSubModule). L'injection croisée permet à l'XP de déclencher les
    // level-up sans couplage dur dans les headers.
    m_experience = new ExperienceModule(this);
    m_experience->setLevelModule(this);
    registerSubModule(m_experience);
}

void LevelModule::setMaxLevel(int maxLevel)
{
    maxLevel = qMax(1, maxLevel);
    if (m_maxLevel == maxLevel)
        return;
    m_maxLevel = maxLevel;
    emit maxLevelChanged();
}

int LevelModule::level(const QString &playerId) const
{
    return m_levels.value(playerId, 1);
}

bool LevelModule::setLevel(const QString &playerId, int level)
{
    if (!effectiveEnabled()) {
        qWarning() << "[LevelModule] setLevel ignoré — module désactivé";
        return false;
    }
    level = qBound(1, level, m_maxLevel);
    const int old = this->level(playerId);
    if (level == old)
        return false;
    m_levels[playerId] = level;
    emit levelChanged(playerId, level);
    if (level > old)
        emit leveledUp(playerId, level);
    return true;
}

void LevelModule::reset()
{
    m_levels.clear();
    // Propage aux sous-modules (réinitialise l'XP).
    GameplayModule::reset();
}
