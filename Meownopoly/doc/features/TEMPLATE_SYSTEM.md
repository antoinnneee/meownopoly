# 🎨 Système de Templates - Documentation Technique

## Vue d'ensemble

Le système de templates permet de créer, sauvegarder et réutiliser des groupes d'éléments (SnapableElements) dans l'éditeur de cartes de Meownopoly. Un template est une "scène" composée de plusieurs éléments avec leurs positions relatives, effets visuels et propriétés, qui peut être placée en un clic sur la carte.

---

## 📋 Liste des fichiers ajoutés/modifiés

### Fichiers C++ créés

| Fichier | Rôle |
|---------|------|
| `cpp/game/map/templatefilemanager.h` | Déclaration du singleton `TemplateFileManager` (méthodes QML `templateExists`/`getAvailableTemplates`/`getTemplatePath`) + helpers statiques de conversion/IO |
| `cpp/game/map/templatefilemanager.cpp` | Implémentation : lecture/écriture/suppression des fichiers JSON et conversion positions absolues ↔ relatives |
| `cpp/game/game_template.cpp` | Méthodes de la classe `Game` : `saveTemplate` / `deleteTemplate` / `loadTemplate` / `getTemplateElementsForPlacement` |

### Fichiers C++ modifiés

| Fichier | Modification |
|---------|--------------|
| `cpp/qmlapp.cpp` | Include de `game/map/templatefilemanager.h` et appel `TemplateFileManager::registerQml()` (un seul module template enregistré) |
| `cpp/game/item_snapable/itemsnapablefactory.h` | Ajout de la méthode `createItemSnapableFromJson(const QJsonObject &json)` |
| `cpp/game/item_snapable/itemsnapablefactory.cpp` | Implémentation de `createItemSnapableFromJson()` |
| `Meownopoly.pro` | Ajout de `game/game_template.cpp`, `game/map/templatefilemanager.cpp` et `game/map/templatefilemanager.h` dans SOURCES/HEADERS (le build principal est CMake, qui ramasse `cpp/*.cpp` via `GLOB_RECURSE` — reconfigurer après ajout) |

### Fichiers QML modifiés

| Fichier | Modification |
|---------|--------------|
| `qml/editor/panel/bottomPanel/bottomMainPanel/templatePanel/TP_Content.qml` | Refonte complète avec interface à 2 onglets (Templates / Créer) |
| `qml/editor/logic/MouseLogic_Template.qml` | Propriété `isPlacementMode` et fonctions `enterPlacementMode()` / `exitPlacementMode()` / `placeTemplateAtCursor()` (logique de placement) |
| `qml/editor/logic/TileLogic.qml` | Réutilisé par le placement : `placeTemplateAtCursor()` appelle `tileLogic.createItemSnapableTile()` (pas de fonction `placeSelectedTemplate()`) |

### Dossier créé (au runtime)

| Dossier | Usage |
|---------|-------|
| `./templates/` | Dossier unique (relatif au CWD) créé automatiquement à la première sauvegarde ; stocke tous les templates sous `<nomNormalisé>_template.json` |

> Il n'y a pas de séparation `default/` vs `user/` ni de templates livrés avec le projet : tous les templates sont générés au runtime dans `./templates/`. Le nom est normalisé (minuscules, espaces → `_`, trim) avant écriture.

---

## 📁 Format JSON d'un Template

```json
{
    "templateInfo": {
        "name": "Nom du template",
        "elementCount": 4,
        "boundingBoxWidth": 6,
        "boundingBoxHeight": 6,
        "creationDate": "2025-01-01T00:00:00"
    },
    "elements": [
        {
            "relativePositionX": 0,
            "relativePositionY": 0,
            "caseData": {
                "name": "Unknown",
                "type": 10
            },
            "decorationParameter": {
                "decorationCategory": "decoration",
                "decorationId": "1",
                "decorationType": "grass"
            },
            "displayParameter": {
                "effectBlur": 0,
                "effectBlurEnabled": false,
                "effectBrightness": 0,
                "effectContrast": 0,
                "effectSaturation": 0,
                "mirrorHorizontal": false,
                "mirrorVertical": false,
                "rotationAngle": 0,
                "unitSizeHeight": 3,
                "unitSizeWidth": 3,
                "zLayer": 5,
                "zOrder": 0.00001
            },
            "tileType": 1
        }
    ]
}
```

### Points clés du format :
- **relativePositionX/Y** : Position relative à l'origine du template (coin supérieur gauche de la bounding box), ajoutée au niveau racine de chaque élément. Ce sont ces champs qui pilotent le placement (`convertToAbsolutePositions` les lit pour recalculer les positions absolues).
- **displayParameter** : Conserve encore `gridRelativePositionX/Y` à la sauvegarde — le strip de ces champs est actuellement désactivé (commenté dans `convertToRelativePositions`). En revanche l'`uniqueId` est retiré à la sauvegarde et régénéré au placement (`regenerateUniqueIds`, avec remappage des liens `next`/`prev`).
- **tileType** : 0 = CaseTile, 1 = DecorationTile, 2 = ExclusionZone, 3 = EffectZone

---

## 🔄 Chronologie détaillée des opérations

### Phase 1 : Création d'un Template

```
1. Utilisateur → TP_Content.qml : Clique sur onglet "Créer"
                    │
                    ▼
2. TP_Content → EditorEnum : Active EM_TEMPLATE via logic.editorMouseMode
                    │
                    ▼
3. Utilisateur → Grille : Sélectionne des éléments existants (MouseLogic_Template)
                    │
                    ▼
4. Utilisateur → TP_Content : Clique "Enregistrer" puis saisit un nom
                    │
                    ▼
5. TP_Content.doSaveTemplate(name) :
   ├── pendingSaveElementsJson = buildElementsJsonFromSelection()
   └── Appelle Game.saveTemplate(name, pendingSaveElementsJson)
                    │
                    ▼
6. Game::saveTemplate() :
   ├── TemplateFileManager::calculateBoundingBox() → {x, y, width, height}
   ├── TemplateFileManager::convertToRelativePositions()
   │   └── Pour chaque élément :
   │       ├── relativePositionX = absX - originX (ajouté au top-level)
   │       ├── relativePositionY = absY - originY
   │       └── Retire uniqueId (gridRelativePositionX/Y conservés)
   ├── Construit templateInfo (name, elementCount, boundingBoxWidth/Height, creationDate)
   └── TemplateFileManager::writeTemplateFile(templateJson, name)
                    │
                    ▼
7. writeTemplateFile() :
   ├── Chemin : ./templates/{nom_normalisé}_template.json
   ├── Crée le dossier ./templates/ si nécessaire
   └── Écrit le JSON formaté
                    │
                    ▼
8. TP_Content.refreshTemplateList() → Met à jour la ListView
```

### Phase 2 : Lecture des Templates

```
1. Application démarre OU TP_Content devient visible
                    │
                    ▼
2. TP_Content.refreshTemplateList() :
   └── Appelle TemplateFileManager.getAvailableTemplates()
                    │
                    ▼
3. TemplateFileManager::getAvailableTemplates() :
   └── Scanne le dossier unique ./templates/*.json
                    │
                    ▼
4. Retourne une QStringList de noms de templates
                    │
                    ▼
5. TP_Content : templateNameList = list (tableau JS de noms)
                    │
                    ▼
6. ListView QML se met à jour (binding model: root.templateNameList)
```

### Phase 3 : Sélection pour placement

```
1. Utilisateur → ListView : Clique sur un template
                    │
                    ▼
2. TP_Content :
   ├── selectedTemplateName = modelData
   └── MouseLogic_Template.enterPlacementMode(name)
                    │
                    ▼
3. enterPlacementMode() :
   ├── placementTemplateData = Game.loadTemplate(name)
   │   └── TemplateFileManager::readTemplateFile()
   └── isPlacementMode = true
                    │
                    ▼
4. TP_Content affiche : "Cliquez sur la grille pour placer..."
```

### Phase 4 : Placement sur la grille

```
1. Utilisateur → Grille : Clique sur espace vide (isPlacementMode actif)
                    │
                    ▼
2. MouseLogic_Template.placeTemplateAtCursor(workAreaX, workAreaY) :
   ├── gridPos = grid.getGridPosition(px, py)
   └── Ajuste la position pour centrer sur la bounding box
                    │
                    ▼
3. Game.getTemplateElementsForPlacement(name, adjustedGridX, adjustedGridY) :
   ├── loadTemplate(name) → QJsonObject
   ├── TemplateFileManager::convertToAbsolutePositions()
   │   └── Pour chaque élément :
   │       ├── gridRelativePositionX = targetX + relativePositionX
   │       └── gridRelativePositionY = targetY + relativePositionY
   └── TemplateFileManager::regenerateUniqueIds()
       └── Nouveaux uniqueId (QUuid) + remappage des liens next/prev
                    │
                    ▼
4. itemSnapableList = Game.generateItems({ snapableTiles: elementsArray })
                    │
                    ▼
5. Pour chaque élément :
   └── logic.tileLogic.createItemSnapableTile(item)
       ├── Crée le composant QML selon tileType
       └── Ajoute à snapableTilesList[]
                    │
                    ▼
6. Éléments apparaissent sur la grille (entourés d'une transaction Game.beginTransaction()/commitTransaction())
```

---

## 📊 Architecture des classes

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              COUCHE QML                                       │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────┐    ┌──────────────────────┐    ┌─────────────────┐ │
│  │   TP_Content.qml    │    │MouseLogic_Template.qml│    │  TileLogic.qml  │ │
│  │  (Interface UI)     │    │  (Logique souris)    │    │(Création tiles) │ │
│  └──────────┬──────────┘    └──────────┬───────────┘    └────────┬────────┘ │
│             │                          │                          │          │
└─────────────┼──────────────────────────┼──────────────────────────┼──────────┘
              │                          │                          │
              ▼                          ▼                          ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                           COUCHE C++ / SINGLETONS                            │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────────────────────┐                                            │
│  │            Game              │  (singleton)                               │
│  │                              │                                            │
│  │ • saveTemplate()             │                                            │
│  │ • deleteTemplate()           │                                            │
│  │ • loadTemplate()             │                                            │
│  │ • getTemplateElementsFor…()  │                                            │
│  └──────────────┬───────────────┘                                            │
│                 │                                                            │
│                 ▼                                                            │
│  ┌──────────────────────────────┐                                            │
│  │      TemplateFileManager     │  (singleton QML)                           │
│  │                              │                                            │
│  │ • templateExists()           │  (Q_INVOKABLE)                             │
│  │ • getAvailableTemplates()    │                                            │
│  │ • getTemplatePath()          │                                            │
│  │ • readTemplateFile() (static)│                                            │
│  │ • writeTemplateFile() (static)│                                           │
│  │ • convertToRelative/Absolute…│  (static)                                 │
│  └──────────────┬───────────────┘                                            │
│                 │                                                            │
└─────────────────┼──────────────────────────────────────────────────────────┘
                  │
                  ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                          SYSTÈME DE FICHIERS                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ./templates/                    ← Dossier unique (créé au runtime)          │
│  └── mon_template_template.json                                              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 API C++ exposée en QML

Le système repose sur deux points d'entrée : le singleton `Game` (méthodes haut niveau de création/suppression/chargement/placement) et le singleton QML `TemplateFileManager` (IO disque + helpers de conversion). Il n'y a ni `TemplateManager`, ni `TemplateModel`, ni `QAbstractListModel` : la ListView est alimentée par un simple tableau JS de noms.

### Game (Singleton)

```cpp
// Méthodes template (game_template.cpp)
bool       saveTemplate(QString name, QJsonArray elementsJson);
bool       deleteTemplate(QString name);
QJsonObject loadTemplate(QString name);
QJsonArray  getTemplateElementsForPlacement(QString name, int targetX, int targetY);
```

### TemplateFileManager (Singleton QML)

```cpp
// Méthodes QML (instance, Q_INVOKABLE)
Q_INVOKABLE bool        templateExists(const QString &templateName);
Q_INVOKABLE QStringList getAvailableTemplates();
Q_INVOKABLE QString     getTemplatePath(const QString &templateName);

// Méthodes statiques (internes) - utilisées par Game
static QJsonObject readTemplateFile(const QString &templateName);
static bool        writeTemplateFile(const QJsonObject &templateData, const QString &templateName);
static bool        removeTemplateFile(const QString &templateName);

// Utilitaires statiques - conversion de positions
static QString     normalizeTemplateName(const QString &templateName);
static QVariantMap calculateBoundingBox(const QJsonArray &elementsArray);
static QJsonArray  convertToRelativePositions(const QJsonArray &elementsArray, int originX, int originY);
static QJsonArray  convertToAbsolutePositions(const QJsonArray &elementsArray, int targetX, int targetY);
static QJsonArray  regenerateUniqueIds(const QJsonArray &elementsArray);
```

---

## 📝 Utilisation dans QML

### Import des modules

```qml
import EditorEnum
import Game
import TemplateFileManager
```

### Exemple : Afficher la liste des templates

La ListView se lie à un simple tableau JS de noms (`templateNameList`), rafraîchi via `TemplateFileManager.getAvailableTemplates()`. Le délégué utilise `modelData` (le nom du template).

```qml
ListView {
    // alimenté par TemplateFileManager.getAvailableTemplates()
    model: root.templateNameList
    delegate: Rectangle {
        property string templateName: modelData
        Text { text: templateName }

        MouseArea {
            onClicked: root.selectedTemplateName = templateName
        }
    }
}
```

### Exemple : Créer un template

```qml
Button {
    text: "Enregistrer"
    onClicked: {
        const elementsJson = []
        for (let i = 0; i < selectedElements.length; i++) {
            const jsonStr = selectedElements[i].snapableParameters.toJSON()
            elementsJson.push(JSON.parse(jsonStr))
        }
        Game.saveTemplate("MonTemplate", elementsJson)
    }
}
```

---

## 🎯 Points d'extension futurs

1. **Aperçu miniature** : Générer une image preview du template
2. **Catégories** : Organiser les templates par catégories (décoration, terrain, bâtiments...)
3. **Import/Export** : Permettre le partage de templates entre utilisateurs
4. **Rotation de template** : Placer le template avec une rotation de 90°/180°/270°
5. **Mise à l'échelle** : Redimensionner le template au moment du placement
6. **Templates imbriqués** : Un template peut contenir d'autres templates

---

*Documentation générée le 23/12/2025*

