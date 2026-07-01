#include "gameplay_module.h"

GameplayModule::GameplayModule(const QString &moduleId,
                               const QString &name,
                               QObject *parent)
    : QObject(parent), m_moduleId(moduleId), m_name(name)
{
}

void GameplayModule::setEnabled(bool enabled)
{
    if (m_enabled == enabled)
        return;
    m_enabled = enabled;
    if (m_enabled)
        onEnabled();
    else
        onDisabled();
    emit enabledChanged();
}

void GameplayModule::reset()
{
    // Rien à purger dans la base ; les modules concrets surchargent.
}
