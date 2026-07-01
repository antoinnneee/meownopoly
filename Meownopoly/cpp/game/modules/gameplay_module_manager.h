#ifndef GAMEPLAY_MODULE_MANAGER_H
#define GAMEPLAY_MODULE_MANAGER_H

#include <QObject>
#include <QList>
#include <QQmlEngine>

// Types complets requis : les Q_PROPERTY renvoient des pointeurs typés
// (HealthModule*…) et moc doit connaître les types complets pour enregistrer
// leur métatype (sinon "Pointer Meta Types must point to fully-defined types").
#include "gameplay_module.h"
#include "health_module.h"
#include "inventory_module.h"
#include "currency_module.h"
#include "stats_module.h"
#include "equipment_module.h"

/// Registre singleton des modules de gameplay activables.
///
/// Instancie et détient les modules concrets (vie, inventaire, monnaie),
/// expose la liste à QML et permet d'activer/désactiver chaque module.
///
/// Enregistré comme singleton QML (module `GameplayModuleManager`), sur le
/// même modèle que `EditorOpBus` / `GameSession`.
///
/// NB : QQmlListProperty n'étant pas une JS array, l'accès à la liste passe
/// par les helpers `moduleAt(int)` / `moduleCount()` / `moduleById(QString)`.
/// Des accesseurs typés directs (`healthModule`…) sont aussi exposés pour le
/// confort côté QML.
class GameplayModuleManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(HealthModule *healthModule READ healthModule CONSTANT)
    Q_PROPERTY(InventoryModule *inventoryModule READ inventoryModule CONSTANT)
    Q_PROPERTY(CurrencyModule *currencyModule READ currencyModule CONSTANT)
    Q_PROPERTY(StatsModule *statsModule READ statsModule CONSTANT)
    Q_PROPERTY(EquipmentModule *equipmentModule READ equipmentModule CONSTANT)

public:
    static void registerQml();
    static GameplayModuleManager *instance();
    static QObject *qmlInstance(QQmlEngine *engine, QJSEngine *scriptEngine);

    // ── Accès à la liste (QQmlListProperty n'est pas une JS array) ─────────
    Q_INVOKABLE int moduleCount() const { return m_modules.size(); }
    Q_INVOKABLE GameplayModule *moduleAt(int index) const;
    Q_INVOKABLE GameplayModule *moduleById(const QString &moduleId) const;

    // ── Activation ────────────────────────────────────────────────────────
    /// Active/désactive un module par id. Retourne false si id inconnu.
    Q_INVOKABLE bool setModuleEnabled(const QString &moduleId, bool enabled);
    Q_INVOKABLE bool isModuleEnabled(const QString &moduleId) const;

    /// Réinitialise l'état de tous les modules (données par joueur).
    Q_INVOKABLE void resetAll();

    // Accesseurs typés directs.
    HealthModule *healthModule() const { return m_health; }
    InventoryModule *inventoryModule() const { return m_inventory; }
    CurrencyModule *currencyModule() const { return m_currency; }
    StatsModule *statsModule() const { return m_stats; }
    EquipmentModule *equipmentModule() const { return m_equipment; }

signals:
    /// Émis quand la liste des modules change (enregistrement) ou qu'un
    /// module est activé/désactivé.
    void modulesChanged();

private:
    explicit GameplayModuleManager(QObject *parent = nullptr);
    static GameplayModuleManager *m_pThis;

    /// Ajoute un module au registre et relaie son enabledChanged.
    void registerModule(GameplayModule *module);

    QList<GameplayModule *> m_modules;
    HealthModule *m_health = nullptr;
    InventoryModule *m_inventory = nullptr;
    CurrencyModule *m_currency = nullptr;
    StatsModule *m_stats = nullptr;
    EquipmentModule *m_equipment = nullptr;
};

#endif // GAMEPLAY_MODULE_MANAGER_H
