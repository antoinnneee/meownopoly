# Héritage QML dans Meownopoly

## Problème résolu

Le signal `nameChanged` de la classe `Case` n'était pas accessible dans les objets `CaseRestArea` en QML à cause d'un problème d'enregistrement des classes intermédiaires.

## Hiérarchie des classes

```
Case (classe de base)
├── Q_PROPERTY(QString name ...)
├── signal nameChanged()
└── CaseCatPerks (classe intermédiaire)
    └── CaseRestArea (classe finale)
```

## Solution implémentée

### 1. Enregistrement complet de la hiérarchie

Les enregistrements vivent dans `CaseFactory::registerCaseQml()` (`cpp/game/case/CaseFactory.cpp`), appelée depuis `Game::registerQml()` (`cpp/game/game.cpp`). Tous les niveaux de la hiérarchie y sont enregistrés :

```cpp
void CaseFactory::registerCaseQml() {
    // Classe de base (non-créable)
    qmlRegisterUncreatableType<Case>("Case", 1, 0, "Case",
                                     "Case is an abstract base class");

    // Classe intermédiaire (non-créable)
    qmlRegisterUncreatableType<CaseCatPerks>("CaseCatPerks", 1, 0, "CaseCatPerks",
                                            "CaseCatPerks is an intermediate base class");

    // Classes finales (créables)
    qmlRegisterType<CaseRestArea>("CaseRestArea", 1, 0, "CaseRestArea");
    qmlRegisterType<CaseKibbleDispenser>("CaseKibbleDispenser", 1, 0, "CaseKibbleDispenser");
    qmlRegisterType<CaseCardBoardBox>("CaseCardBoardBox", 1, 0, "CaseCardBoardBox");
    qmlRegisterType<CaseCatNip>("CaseCatNip", 1, 0, "CaseCatNip");
    qmlRegisterType<CaseJail>("CaseJail", 1, 0, "CaseJail");
    qmlRegisterType<CaseToJail>("CaseToJail", 1, 0, "CaseToJail");
    qmlRegisterType<CaseCatDoor>("CaseCatDoor", 1, 0, "CaseCatDoor");
    qmlRegisterType<CaseFreeNap>("CaseFreeNap", 1, 0, "CaseFreeNap");
    qmlRegisterType<CaseCatDevice>("CaseCatDevice", 1, 0, "CaseCatDevice");
}
```

### 2. Includes ajoutés

Dans `CaseFactory.cpp` :
```cpp
#include "CaseRestArea.h"  // tire transitivement CaseCatPerks.h puis Case.h
#include "CaseCardBoardBox.h"
#include "CaseCatNip.h"
#include "CaseJail.h"
#include "CaseToJail.h"
#include "CaseCatDoor.h"
#include "CaseFreeNap.h"
#include "CaseCatDevice.h"
#include "CaseKibbleDispenser.h"
```

## Utilisation en QML

### Signal nameChanged hérité

```qml
CaseRestArea {
    id: restArea
    name: "Aire de repos luxueuse"
    
    // Signal hérité de Case
    onNameChanged: {
        console.log("Le nom a changé:", name)
        // Votre logique ici
    }
    
    // Autres signaux hérités
    onTypeChanged: {
        console.log("Type:", type)
    }
}
```

### Accès aux propriétés héritées

```qml
// Toutes ces propriétés sont héritées de Case
Text { text: restArea.name }      // Hérité de Case
Text { text: restArea.type }      // Hérité de Case

// Propriétés de CaseCatPerks
Text { text: restArea.price }     // Hérité de CaseCatPerks
```

## Règles importantes pour l'héritage QML

1. **Enregistrer toute la hiérarchie** : Toutes les classes de la chaîne d'héritage doivent être enregistrées avec `qmlRegisterType` ou `qmlRegisterUncreatableType`.

2. **Ordre d'enregistrement** : Enregistrer de la classe de base vers les classes dérivées.

3. **Q_OBJECT macro** : Toutes les classes doivent avoir la macro `Q_OBJECT`.

4. **Signaux et propriétés** : Les signaux et propriétés `Q_PROPERTY` sont automatiquement hérités.

5. **Namespace cohérent** : Utiliser le même module/namespace pour toute la hiérarchie.

## Vérification

Pour vérifier que l'héritage fonctionne :

1. Compilez le projet
2. Instanciez une `CaseRestArea` dans une scène existante
3. Changez le nom de la `CaseRestArea`
4. Vérifiez que le signal `nameChanged` se déclenche dans la console

Le signal `nameChanged` est maintenant accessible dans tous les objets `CaseRestArea` en QML ! 