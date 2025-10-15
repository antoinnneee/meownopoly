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

Dans `game.cpp`, tous les niveaux de la hiérarchie sont maintenant enregistrés :

```cpp
void Game::registerQml() {
    // Classe de base (non-créable)
    qmlRegisterUncreatableType<Case>("Case", 1, 0, "Case", 
                                     "Case is an abstract base class");
    
    // Classe intermédiaire (non-créable)
    qmlRegisterUncreatableType<CaseCatPerks>("CaseCatPerks", 1, 0, "CaseCatPerks", 
                                            "CaseCatPerks is an intermediate base class");
    
    // Classe finale (créable)
    qmlRegisterType<CaseRestArea>("CaseRestArea", 1, 0, "CaseRestArea");
}
```

### 2. Includes ajoutés

Dans `game.h` :
```cpp
#include "case/CaseCatPerks.h"
#include "case/CaseRestArea.h"
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
    onPositionChanged: {
        console.log("Position:", position)
    }
    
    onTypeChanged: {
        console.log("Type:", type)
    }
}
```

### Accès aux propriétés héritées

```qml
// Toutes ces propriétés sont héritées de Case
Text { text: restArea.name }      // Hérité de Case
Text { text: restArea.position }  // Hérité de Case  
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

## Fichiers de test

- `qml/test/TEST_INHERITANCE.qml` : Test basique de l'héritage
- `qml/test/TEST_CASE_INHERITANCE.qml` : Exemple pratique avec animations

## Vérification

Pour vérifier que l'héritage fonctionne :

1. Compilez le projet
2. Ouvrez un des fichiers de test
3. Changez le nom d'une `CaseRestArea`
4. Vérifiez que le signal `nameChanged` se déclenche dans la console

Le signal `nameChanged` est maintenant accessible dans tous les objets `CaseRestArea` en QML ! 