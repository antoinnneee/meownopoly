---
name: gameplay-module
description: Méthode pour ajouter un module de gameplay activable à Meownopoly (système de jeu optionnel type vie, inventaire, monnaie). Utiliser quand l'utilisateur demande de créer/étendre un module de gameplay, un système de jeu activable, ou d'ajouter une section au banc d'essai des modules.
---

# Ajouter un module de gameplay activable

Un **module de gameplay** est un système de jeu optionnel (vie, inventaire, monnaie…) encapsulé dans un QObject activable/désactivable, enregistré dans le singleton `GameplayModuleManager` et testable via la page "🧩 Modules Gameplay" du menu titre.

Architecture de référence : `Meownopoly/cpp/game/modules/` (base + manager + 3 modules exemples) et `Meownopoly/qml/test/GameplayModulesTestPage.qml` (banc d'essai). `HealthModule` est le modèle canonique à copier.

## Principes de conception (non négociables)

- **Données indexées par `playerId` (QString)** en v1 — pas de branchement Catway/GameSession. Un joueur inconnu est créé implicitement avec des valeurs par défaut au premier accès.
- **No-op si désactivé** : toute mutation commence par `if (!enabled()) { qWarning() << ...; return false; }`. Les lectures restent permises.
- **Signaux de notification pour chaque mutation** (ex : `healthChanged(playerId, hp, maxHp)`) — c'est ce que le banc d'essai loggue, et ce sur quoi le futur code de jeu se branchera.
- **`reset()` surchargé** pour purger les conteneurs par joueur (appelé par `GameplayModuleManager::resetAll()`).
- Jamais de signal custom suffixé `Changed` en dehors des notify de Q_PROPERTY (collision avec les signaux auto-générés QML).

## Étapes

### 1. Classe C++ du module — `cpp/game/modules/<nom>_module.{h,cpp}`

Hériter de `GameplayModule` (qui fournit `name`, `moduleId`, `enabled` + hooks `onEnabled()`/`onDisabled()`). Dans le ctor, appeler la base avec un `moduleId` stable en kebab/camel simple (ex : `"health"`) et un nom lisible français.

```cpp
class QuestModule : public GameplayModule {
    Q_OBJECT
public:
    explicit QuestModule(QObject *parent = nullptr);
    // Lectures : Q_INVOKABLE, autorisées même désactivé
    Q_INVOKABLE int questCount(const QString &playerId);
    // Mutations : Q_INVOKABLE bool, no-op si désactivé
    Q_INVOKABLE bool addQuest(const QString &playerId, const QString &questId);
    void reset() override;
signals:
    void questAdded(const QString &playerId, const QString &questId);
private:
    QHash<QString, QStringList> m_quests;  // état par joueur
};
```

### 2. Enregistrement dans le manager — `gameplay_module_manager.{h,cpp}`

Quatre points à toucher :
1. **Header** : `#include "<nom>_module.h"` (include COMPLET obligatoire — moc Qt 6.11 refuse les forward declarations pour les pointeurs en Q_PROPERTY : "Pointer Meta Types must point to fully-defined types").
2. **Header** : `Q_PROPERTY(QuestModule *questModule READ questModule CONSTANT)` + accesseur typé + membre `m_quest`.
3. **Ctor** (`.cpp`) : `m_quest = new QuestModule(this);` puis `registerModule(m_quest);` (le parentage au manager règle la durée de vie ; `registerModule` relaie `enabledChanged` → `modulesChanged`).
4. **`registerQml()`** (`.cpp`) : `qmlRegisterUncreatableType<QuestModule>("GameplayModuleManager", 1, 0, "QuestModule", ...)` pour typer les retours côté QML.

Rien à faire dans `qmlapp.cpp` (le `GameplayModuleManager::registerQml()` global y est déjà appelé, ligne ~115).

### 3. CMake — reconfigurer

Les `.cpp` sont ramassés par GLOB_RECURSE mais la liste est **figée au configure**. Après ajout de fichiers, relancer le configure avant le build (sinon erreurs de link) :

```powershell
$env:PATH = "C:\Qt\Tools\mingw1310_64\bin;C:\Qt\6.11.0\mingw_64\bin;$env:PATH"
& "C:/Qt/Tools/CMake_64/bin/cmake.exe" -S Meownopoly -B build -G "Ninja Multi-Config" -DCMAKE_CXX_COMPILER="C:/Qt/Tools/mingw1310_64/bin/g++.exe" -DCMAKE_PREFIX_PATH="C:/Qt/6.11.0/mingw_64" -DCMAKE_MAKE_PROGRAM="C:/Qt/Tools/Ninja/ninja.exe"
& "C:/Qt/Tools/CMake_64/bin/cmake.exe" --build build --config Release --target Meownopoly
```

### 4. Section de test — `qml/test/GameplayModulesTestPage.qml`

Ajouter une section sur le modèle des existantes :
- `readonly property var _quest: GameplayModuleManager.questModule` en tête de `root`.
- Un `MeowSwitch` d'activation : `checked` bindé sur `module.enabled`, `onToggled: module.enabled = checked`.
- Des contrôles de test (kit `ui_item` : `MeowButton`, `MeowTextField`, `MeowSpinBox`…) opérant sur les joueurs de test `root._playerA`/`_playerB`.
- Un bloc `Connections { target: root._quest }` qui pousse chaque signal dans le log commun via `root._log("📜 ...")` — choisir un emoji distinctif par module.
- Si l'UI affiche un état, le tenir dans des propriétés miroir `_xxx` rafraîchies par les signaux (les retours de `Q_INVOKABLE` ne sont pas des bindings — QML ne ré-évalue pas tout seul).

### 5. Valider

Build Release complet (étape 3), puis lancer `build/Release/Meownopoly.exe` → menu titre → "🧩 Modules Gameplay" → vérifier : switch off = boutons inertes (warnings console), switch on = mutations visibles + lignes dans le journal d'événements.

## Pièges connus

- **Q_PROPERTY name, pas getter name** : QML lit `module.enabled`, pas `module.isEnabled()`.
- **QQmlListProperty n'est pas une JS array** : l'accès à la liste des modules passe par `moduleAt(i)`/`moduleCount()`/`moduleById(id)`, ou par les accesseurs typés (`healthModule`…).
- **Listes vers QML** : renvoyer des `QVariantList` de `QVariantMap` (cf. `InventoryModule::items()`) directement consommables par un `ListView`/`Repeater` — pas de `QList<CustomStruct>`.
- **Style** : tout passe par `Theme` (`import theme`) + kit `ui_item` ; jamais de `font.pointSize`.
- **Toggle switch + binding** : `checked: module.enabled` + écriture impérative dans `onToggled` peut émettre un warning `qt.qml.binding.removal` bénin — la valeur reste cohérente car `enabledChanged` ré-évalue.
