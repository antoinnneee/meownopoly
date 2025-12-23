# 🎨 Système de Templates - Documentation Technique

## Vue d'ensemble

Le système de templates permet de créer, sauvegarder et réutiliser des groupes d'éléments (SnapableElements) dans l'éditeur de cartes de Meownopoly. Un template est une "scène" composée de plusieurs éléments avec leurs positions relatives, effets visuels et propriétés, qui peut être placée en un clic sur la carte.

---

## 📋 Liste des fichiers ajoutés/modifiés

### Fichiers C++ créés (`cpp/game/template/`)

| Fichier | Rôle |
|---------|------|
| `templateinfo.h` | Classe contenant les métadonnées d'un template (nom, dimensions, nombre d'éléments, auteur, etc.) |
| `templateinfo.cpp` | Implémentation de TemplateInfo avec sérialisation JSON |
| `templatefilemanager.h` | Gestionnaire de fichiers JSON pour les templates (lecture/écriture/suppression) |
| `templatefilemanager.cpp` | Implémentation avec conversion positions absolues ↔ relatives |
| `templatemodel.h` | Modèle QAbstractListModel pour afficher les templates dans une ListView QML |
| `templatemodel.cpp` | Implémentation du modèle avec chargement des templates |
| `templatemanager.h` | Façade principale exposée en QML comme singleton |
| `templatemanager.cpp` | Logique de création, sélection et placement des templates |

### Fichiers C++ modifiés

| Fichier | Modification |
|---------|--------------|
| `cpp/qmlapp.cpp` | Ajout des includes et appels `registerQml()` pour les 4 modules template |
| `cpp/game/item_snapable/itemsnapablefactory.h` | Ajout de la méthode `createItemSnapableFromJson(const QJsonObject &json)` |
| `cpp/game/item_snapable/itemsnapablefactory.cpp` | Implémentation de `createItemSnapableFromJson()` |
| `Meownopoly.pro` | Ajout des 8 nouveaux fichiers sources/headers dans SOURCES et HEADERS |

### Fichiers QML modifiés

| Fichier | Modification |
|---------|--------------|
| `qml/editor/panel/bottomPanel/bottomMainPanel/templatePanel/TP_Content.qml` | Refonte complète avec interface à 2 onglets (Templates / Créer) |
| `qml/editor/logic/MouseLogic_Template.qml` | Ajout de la propriété `isPlacingTemplate` et logique de placement |
| `qml/editor/logic/TileLogic.qml` | Ajout de la fonction `placeSelectedTemplate()` et imports |

### Dossiers créés

| Dossier | Usage |
|---------|-------|
| `template/default/` | Templates fournis par défaut (non modifiables par l'utilisateur) |
| `template/user/` | Templates créés par l'utilisateur |

### Fichiers JSON exemple

| Fichier | Description |
|---------|-------------|
| `template/default/corner_grass_template.json` | Template d'exemple avec 4 tuiles d'herbe en carré |

---

## 📁 Format JSON d'un Template

```json
{
    "templateInfo": {
        "name": "Nom du template",
        "description": "Description optionnelle",
        "creationDate": "2025-01-01T00:00:00",
        "author": "Nom de l'auteur",
        "version": 1,
        "boundingBoxWidth": 6,
        "boundingBoxHeight": 6,
        "originOffsetX": 0,
        "originOffsetY": 0,
        "elementCount": 4,
        "thumbnailPath": "",
        "isDefault": false
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
- **relativePositionX/Y** : Position relative à l'origine du template (coin supérieur gauche de la bounding box)
- **displayParameter** : Ne contient PAS `gridRelativePositionX/Y` (calculées au placement)
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
3. Utilisateur → Grille : Clique sur des éléments existants
                    │
                    ▼
4. MouseLogic_Template.clickedLeft() :
   ├── Détecte le clic sur un élément
   ├── selectElement() ajoute à selectedElements[]
   └── updateBoundingRectangle() affiche rectangle vert
                    │
                    ▼
5. Utilisateur → TP_Content : Entre un nom + clique "Créer Template"
                    │
                    ▼
6. TP_Content.createTemplate() :
   ├── Récupère selectedElements[] depuis MouseLogic_Template
   ├── Convertit chaque element.snapableParameters.toJSON()
   └── Appelle TemplateManager.createTemplateFromJson(name, jsonArray)
                    │
                    ▼
7. TemplateManager.createTemplateFromJson() :
   ├── calculateBoundingBox() → {minX, minY, maxX, maxY}
   ├── Crée templateInfo avec métadonnées
   ├── TemplateFileManager::convertElementsToTemplateFormat()
   │   └── Pour chaque élément :
   │       ├── relativePositionX = absX - minX
   │       ├── relativePositionY = absY - minY
   │       └── Retire gridRelativePositionX/Y
   └── TemplateFileManager::saveTemplate()
                    │
                    ▼
8. TemplateFileManager.saveTemplate() :
   ├── Chemin : ./template/user/{nom_normalisé}_template.json
   ├── Crée dossier si nécessaire
   └── Écrit JSON formaté
                    │
                    ▼
9. TemplateModel.refresh() → Met à jour la ListView
```

### Phase 2 : Lecture des Templates

```
1. Application démarre OU TP_Content devient visible
                    │
                    ▼
2. TemplateModel.loadTemplates() :
   ├── beginResetModel()
   └── Vide m_templates[]
                    │
                    ▼
3. Charge templates par défaut :
   ├── TemplateFileManager::getAvailableTemplates(DEFAULT)
   │   └── Scanne ./template/default/*.json
   └── Pour chaque : loadTemplateInfo(name, DEFAULT)
                    │
                    ▼
4. Charge templates utilisateur :
   ├── TemplateFileManager::getAvailableTemplates(USER)
   │   └── Scanne ./template/user/*.json
   └── Pour chaque : loadTemplateInfo(name, USER)
                    │
                    ▼
5. loadTemplateInfo() :
   ├── TemplateFileManager::readTemplateFile()
   │   ├── Ouvre fichier JSON
   │   ├── Parse JSON
   │   └── Retourne QJsonObject
   ├── Extrait templateInfo
   └── Ajoute TemplateData à m_templates[]
                    │
                    ▼
6. endResetModel() + emit signals
                    │
                    ▼
7. ListView QML se met à jour (binding model: TemplateModel)
```

### Phase 3 : Sélection pour placement

```
1. Utilisateur → ListView : Clique sur un template
                    │
                    ▼
2. TP_Content :
   ├── selectedTemplateName = model.name
   └── TemplateManager.selectTemplate(name)
                    │
                    ▼
3. TemplateManager.selectTemplate() :
   ├── Détermine type (DEFAULT ou USER)
   ├── TemplateFileManager::readTemplateFile()
   ├── Stocke dans m_currentTemplateData
   └── Émet currentTemplateDataChanged()
                    │
                    ▼
4. MouseLogic_Template :
   └── isPlacingTemplate = TemplateManager.hasCurrentTemplate → true
                    │
                    ▼
5. TP_Content affiche : "Cliquez sur la grille pour placer..."
```

### Phase 4 : Placement sur la grille

```
1. Utilisateur → Grille : Clique sur espace vide
                    │
                    ▼
2. MouseLogic_Template.clickedLeft() :
   └── Condition : clickElement.length === 0 
                   && isPlacingTemplate 
                   && !hasMoved
                    │
                    ▼
3. Calcul position :
   └── gridPos = grid.getGridPosition(workAreaPos.x, workAreaPos.y)
                    │
                    ▼
4. TileLogic.placeSelectedTemplate(gridPos.x, gridPos.y)
                    │
                    ▼
5. TileLogic.placeSelectedTemplate() :
   ├── Vérifie TemplateManager.hasCurrentTemplate
   ├── bounds = TemplateManager.getCurrentTemplateBounds()
   ├── Ajuste position pour centrer
   └── elementsJson = TemplateManager.generateTemplateElementsJson()
                    │
                    ▼
6. TemplateManager.generateTemplateElementsJson() :
   └── TemplateFileManager::convertTemplateElementsToMapFormat()
       └── Pour chaque élément :
           ├── gridRelativePositionX = targetX + relativePositionX
           ├── gridRelativePositionY = targetY + relativePositionY
           ├── Génère nouveau uniqueId (QUuid)
           └── Réinitialise next/prev = []
                    │
                    ▼
7. Pour chaque élément JSON :
   ├── ItemSnapableFactory.createItemSnapableFromJson(data)
   └── TileLogic.createItemSnapable(snapableParameters)
       ├── Crée composant QML selon tileType
       ├── Ajoute à snapableTilesList[]
       └── snapToGridFromGridPos()
                    │
                    ▼
8. Éléments apparaissent sur la grille
                    │
                    ▼
9. logic.saveMap(MapTypes.UNDOREDO) → Sauvegarde pour undo/redo
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
│  ┌─────────────────────┐    ┌──────────────────────┐                        │
│  │   TemplateManager   │◄───│    TemplateModel     │                        │
│  │     (Singleton)     │    │  (QAbstractListModel)│                        │
│  │                     │    │                      │                        │
│  │ • createTemplate()  │    │ • loadTemplates()    │                        │
│  │ • selectTemplate()  │    │ • refresh()          │                        │
│  │ • generateElements()│    │ • getTemplateData()  │                        │
│  └──────────┬──────────┘    └──────────┬───────────┘                        │
│             │                          │                                     │
│             └────────────┬─────────────┘                                     │
│                          ▼                                                   │
│             ┌────────────────────────┐                                       │
│             │  TemplateFileManager   │                                       │
│             │      (Singleton)       │                                       │
│             │                        │                                       │
│             │ • readTemplateFile()   │                                       │
│             │ • saveTemplate()       │                                       │
│             │ • convertElements...() │                                       │
│             └────────────┬───────────┘                                       │
│                          │                                                   │
└──────────────────────────┼───────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────────────────────┐
│                          SYSTÈME DE FICHIERS                                  │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ./template/                                                                 │
│  ├── default/                    ← Templates par défaut (lecture seule)     │
│  │   └── corner_grass_template.json                                         │
│  └── user/                       ← Templates utilisateur (lecture/écriture) │
│      └── mon_template_template.json                                         │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔧 API C++ exposée en QML

### TemplateManager (Singleton)

```cpp
// Propriétés
Q_PROPERTY(QString currentTemplateName ...)
Q_PROPERTY(QJsonObject currentTemplateData ...)
Q_PROPERTY(bool hasCurrentTemplate ...)

// Méthodes
Q_INVOKABLE bool createTemplateFromElements(QString name, QVariantList elements);
Q_INVOKABLE bool createTemplateFromJson(QString name, QJsonArray elementsJson);
Q_INVOKABLE bool selectTemplate(QString name);
Q_INVOKABLE void clearSelection();
Q_INVOKABLE QJsonArray generateTemplateElementsJson(int targetX, int targetY);
Q_INVOKABLE QVariantMap getCurrentTemplateBounds();
Q_INVOKABLE bool deleteTemplate(QString name);
Q_INVOKABLE void refreshTemplates();

// Signaux
signal templateCreated(QString name);
signal templateDeleted(QString name);
signal templateSelected(QString name);
signal templatePlaced(int gridX, int gridY, int elementCount);
```

### TemplateModel (Singleton, QAbstractListModel)

```cpp
// Rôles pour ListView
enum TemplateRoles {
    NameRole, DescriptionRole, CreationDateRole, AuthorRole,
    VersionRole, BoundingBoxWidthRole, BoundingBoxHeightRole,
    OriginOffsetXRole, OriginOffsetYRole, ElementCountRole,
    ThumbnailPathRole, IsDefaultRole, FilePathRole
};

// Méthodes
Q_INVOKABLE void refresh();
Q_INVOKABLE void loadTemplates();
Q_INVOKABLE QJsonObject getTemplateData(int index);
Q_INVOKABLE QJsonObject getTemplateDataByName(QString name);
Q_INVOKABLE int indexOf(QString name);
```

### TemplateFileManager (Singleton)

```cpp
// Types
enum TemplateType { DEFAULT, USER };

// Méthodes
Q_INVOKABLE bool templateExists(QString name, TemplateType type);
Q_INVOKABLE QStringList getAvailableTemplates(TemplateType type);
Q_INVOKABLE QString createTemplateFile(QString name);
Q_INVOKABLE bool deleteTemplate(QString name);
Q_INVOKABLE bool isDefaultTemplate(QString name);

// Méthodes statiques (internes)
static QJsonObject readTemplateFile(QString name, TemplateType type);
static bool saveTemplate(QJsonObject data, QString name, TemplateType type);
static QJsonArray convertElementsToTemplateFormat(QJsonArray elements, int originX, int originY);
static QJsonArray convertTemplateElementsToMapFormat(QJsonArray elements, int targetX, int targetY);
```

---

## 📝 Utilisation dans QML

### Import des modules

```qml
import TemplateManager
import TemplateModel
import TemplateFileManager
```

### Exemple : Afficher la liste des templates

```qml
ListView {
    model: TemplateModel
    delegate: Rectangle {
        Text { text: model.name }
        Text { text: model.elementCount + " éléments" }
        Text { text: model.boundingBoxWidth + "×" + model.boundingBoxHeight }
        
        MouseArea {
            onClicked: TemplateManager.selectTemplate(model.name)
        }
    }
}
```

### Exemple : Créer un template

```qml
Button {
    text: "Créer Template"
    onClicked: {
        var elementsJson = []
        for (var i = 0; i < selectedElements.length; i++) {
            var jsonStr = selectedElements[i].snapableParameters.toJSON()
            elementsJson.push(JSON.parse(jsonStr))
        }
        TemplateManager.createTemplateFromJson("MonTemplate", elementsJson)
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

