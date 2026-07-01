#include "gameplay_module_manager.h"

#include "gameplay_module.h"
#include "health_module.h"
#include "inventory_module.h"
#include "currency_module.h"

#include <QQmlEngine>

GameplayModuleManager *GameplayModuleManager::m_pThis = nullptr;

GameplayModuleManager::GameplayModuleManager(QObject *parent) : QObject(parent)
{
    // Instancie les modules concrets. Ils sont parentés au manager (durée
    // de vie = celle du singleton).
    m_health = new HealthModule(this);
    m_inventory = new InventoryModule(this);
    m_currency = new CurrencyModule(this);

    registerModule(m_health);
    registerModule(m_inventory);
    registerModule(m_currency);
}

GameplayModuleManager *GameplayModuleManager::instance()
{
    if (!m_pThis)
        m_pThis = new GameplayModuleManager();
    return m_pThis;
}

QObject *GameplayModuleManager::qmlInstance(QQmlEngine * /*engine*/, QJSEngine * /*scriptEngine*/)
{
    return instance();
}

void GameplayModuleManager::registerQml()
{
    qmlRegisterSingletonType<GameplayModuleManager>(
        "GameplayModuleManager", 1, 0, "GameplayModuleManager",
        &GameplayModuleManager::qmlInstance);

    // Types de base exposés (uncreatable) pour typer les objets renvoyés
    // par moduleAt/moduleById et les accesseurs typés côté QML.
    qmlRegisterUncreatableType<GameplayModule>(
        "GameplayModuleManager", 1, 0, "GameplayModule",
        QStringLiteral("Accessible via GameplayModuleManager"));
    qmlRegisterUncreatableType<HealthModule>(
        "GameplayModuleManager", 1, 0, "HealthModule",
        QStringLiteral("Accessible via GameplayModuleManager.healthModule"));
    qmlRegisterUncreatableType<InventoryModule>(
        "GameplayModuleManager", 1, 0, "InventoryModule",
        QStringLiteral("Accessible via GameplayModuleManager.inventoryModule"));
    qmlRegisterUncreatableType<CurrencyModule>(
        "GameplayModuleManager", 1, 0, "CurrencyModule",
        QStringLiteral("Accessible via GameplayModuleManager.currencyModule"));
}

void GameplayModuleManager::registerModule(GameplayModule *module)
{
    if (!module || m_modules.contains(module))
        return;
    m_modules.append(module);
    // Relaie tout changement d'activation vers modulesChanged (l'UI peut
    // s'y accrocher pour un rafraîchissement global).
    connect(module, &GameplayModule::enabledChanged,
            this, &GameplayModuleManager::modulesChanged);
    emit modulesChanged();
}

GameplayModule *GameplayModuleManager::moduleAt(int index) const
{
    if (index < 0 || index >= m_modules.size())
        return nullptr;
    return m_modules.at(index);
}

GameplayModule *GameplayModuleManager::moduleById(const QString &moduleId) const
{
    for (GameplayModule *m : m_modules) {
        if (m->moduleId() == moduleId)
            return m;
    }
    return nullptr;
}

bool GameplayModuleManager::setModuleEnabled(const QString &moduleId, bool enabled)
{
    GameplayModule *m = moduleById(moduleId);
    if (!m)
        return false;
    m->setEnabled(enabled);
    return true;
}

bool GameplayModuleManager::isModuleEnabled(const QString &moduleId) const
{
    GameplayModule *m = moduleById(moduleId);
    return m ? m->enabled() : false;
}

void GameplayModuleManager::resetAll()
{
    for (GameplayModule *m : m_modules)
        m->reset();
}
