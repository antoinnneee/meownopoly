#include "gameplay_module.h"

GameplayModule::GameplayModule(const QString &moduleId,
                               const QString &name,
                               QObject *parent)
    : QObject(parent), m_moduleId(moduleId), m_name(name)
{
}

bool GameplayModule::effectiveEnabled() const
{
    if (!m_enabled)
        return false;
    return m_parentModule ? m_parentModule->effectiveEnabled() : true;
}

void GameplayModule::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    const bool wasEffective = effectiveEnabled();
    m_enabled = enabled;
    if (m_enabled)
        onEnabled();
    else
        onDisabled();
    emit enabledChanged();
    // Si l'état effectif a réellement changé, le propager (à soi + enfants).
    if (effectiveEnabled() != wasEffective)
        notifyEffectiveEnabledChanged();
}

void GameplayModule::notifyEffectiveEnabledChanged()
{
    emit effectiveEnabledChanged();
    // Propager aux sous-modules : leur effectiveEnabled dépend du nôtre. Il ne
    // change QUE pour les enfants dont le flag propre est activé (un enfant
    // désactivé reste effectivement désactivé quel que soit le parent).
    for (GameplayModule *sub : m_subModules) {
        if (sub->m_enabled)
            sub->notifyEffectiveEnabledChanged();
    }
}

void GameplayModule::registerSubModule(GameplayModule *sub)
{
    if (!sub || m_subModules.contains(sub))
        return;
    sub->setParent(this);          // ownership QObject
    sub->m_parentModule = this;
    m_subModules.append(sub);
}

GameplayModule *GameplayModule::subModuleAt(int index) const
{
    if (index < 0 || index >= m_subModules.size())
        return nullptr;
    return m_subModules.at(index);
}

GameplayModule *GameplayModule::subModuleById(const QString &moduleId) const
{
    for (GameplayModule *sub : m_subModules) {
        if (sub->moduleId() == moduleId)
            return sub;
        if (GameplayModule *nested = sub->subModuleById(moduleId))
            return nested;
    }
    return nullptr;
}

void GameplayModule::reset()
{
    // La base propage le reset aux sous-modules ; les modules concrets qui
    // surchargent reset() doivent appeler GameplayModule::reset() pour conserver
    // cette propagation.
    for (GameplayModule *sub : m_subModules)
        sub->reset();
}
