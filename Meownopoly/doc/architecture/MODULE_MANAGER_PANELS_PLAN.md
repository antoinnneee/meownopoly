# Plan — Gestionnaire de modules ↔ panels de l'éditeur

> **But.** Relier le nouveau `ModuleManager` (barre horizontale en haut de l'éditeur)
> aux menus existants de `qml/editor/panel/bottomPanel/`, de sorte qu'un panel de
> sélection (asset / case / template / zone / joueur …) ne soit affiché **que**
> lorsqu'il a été cliqué dans le gestionnaire, **un seul à la fois**.
>
> Ce plan inclut un **travail préliminaire de réorganisation des dossiers**
> (déplacement de `moduleManager` et aplatissement de l'arbo `bottomPanel`) à
> exécuter **avant** le câblage fonctionnel.
>
> Statut : **proposé**. Date : 2026-06-17. Branche cible : `V2_Valou`.

---

## 0. Contexte technique (mécanisme des modules QML du repo)

⚠️ **Indispensable à comprendre avant tout déplacement de dossier.** Le projet
n'utilise PAS `qt_add_qml_module`. Les modules QML sont gérés « à l'ancienne »
via 4 sources qui doivent rester cohérentes :

1. **`qml.qrc`** (`<qresource prefix="/">`) — enregistre chaque fichier `.qml`
   et `qmldir` comme ressource Qt à `qrc:/qml/...`. Déplacer un fichier =
   mettre à jour son chemin `<file>` ici.
2. **`cpp/qmlapp.cpp`** (lignes ~203-211) — une série de `addImportPath("qrc:/qml/...")`
   par niveau de dossier. Un `import <Module>` est résolu en cherchant un
   sous-dossier `<Module>/qmldir` **directement sous l'un de ces roots**.
   → Convention de fer : **nom du dossier == nom du module (`module X`) == nom de l'import (`import X`)**.
3. **`qml/editor/qmldir`** (`module editor`) — module « maître » qui ré-exporte
   certains panels **par chemin relatif** :
   ```
   SelectionPanel    1.0 panel/bottomPanel/bottomMainPanel/SelectionPanel.qml
   BottomSidePanel   1.0 panel/bottomPanel/bottomSidePanel/BottomSidePanel.qml
   ModuleManager     1.0 panel/bottomPanel/bottomMainPanel/menuSelectionPanel/moduleManager/ModuleManager.qml
   VisualEffectsPanel 1.0 panel/bottomPanel/bottomSidePanel/visualEffectPanel/VisualEffectsPanel.qml
   CaseConfigurationPanelSection 1.0 panel/bottomPanel/bottomSidePanel/caseConfigPanel/CaseConfigurationPanelSection.qml
   ConnectionsConfigurationSection 1.0 panel/bottomPanel/bottomSidePanel/connectionConfigPanel/ConnectionsConfigurationSection.qml
   ZoneConfigurationPanelSection 1.0 panel/bottomPanel/bottomSidePanel/zoneConfigPanel/ZoneConfigurationPanelSection.qml
   MapInfoPanel      1.0 panel/mapInfoPanel/MapInfoPanel.qml
   ```
   → Ces chemins **doivent** être mis à jour à chaque déplacement de fichier.
4. **Les `qmldir` locaux** de chaque dossier — `module <nom>` + liste des types.

**Règle d'or pour ne rien casser :** on **conserve le nom de chaque dossier-module**
(`assetSelectionPanel`, `caseSelectionPanel`, `editorBottomPanel`, `caseConfigPanel`,
…). Ainsi les ~40 instructions `import X` réparties dans l'arbre **n'ont pas à
changer** ; seuls changent (a) les chemins physiques dans `qml.qrc`, (b) les
`addImportPath` dans `qmlapp.cpp`, (c) les chemins relatifs dans `editor/qmldir`.

### Résolution actuelle des imports (à reproduire après déplacement)

`addImportPath` actuels et ce qu'ils exposent :

| Import path (`qrc:/qml/...`) | Modules rendus résolvables (sous-dossiers) |
|---|---|
| `` (`qrc:/qml`) | `ui_item`, `world3d`, `theme`, `editor`*, … |
| `editor` | (rien d'utile en direct, mais `module editor` est ici) |
| `editor/panel` | `mapInfoPanel`, `bottomPanel`*, `zonePanel`* |
| `editor/panel/bottomPanel` | `bottomMainPanel`, `bottomSidePanel` |
| `editor/panel/mapInfoPanel` | `mapInfoPanelMain` |
| `editor/panel/bottomPanel/bottomMainPanel` | `assetSelectionPanel`, `caseSelectionPanel`, `editorBottomPanel`, `menuSelectionPanel`, `zonePanel`, `templatePanel` |
| `editor/panel/bottomPanel/bottomSidePanel` | `caseConfigPanel`, `connectionConfigPanel`, `sidePanel`, `visualEffectPanel`, `zoneConfigPanel` |
| `editor/panel/bottomPanel/bottomMainPanel/caseSelectionPanel` | `caseSelectionPanelMain` |
| `editor/panel/bottomPanel/bottomMainPanel/assetSelectionPanel` | `playerConfigPanel`, `screenEffectPanel` |

\* commentaires du code ; certains modules listés n'existent pas réellement
(voir « modules morts » §1.3).

---

## 1. État des lieux

### 1.1 Arborescence actuelle

```
qml/editor/
├── Editor.qml                         (import editor, playerConfigPanel)
├── qmldir  (module editor — ré-exporte SelectionPanel/BottomSidePanel/ModuleManager/…)
├── MenuMapAtStart.qml                 (import playerConfigPanel)
├── logic/MouseLogic_Base.qml          (import bottomMainPanel — vestigial, voir §1.4)
└── panel/
    ├── mapInfoPanel/                  (inchangé par ce plan)
    └── bottomPanel/                   ← À SUPPRIMER (wrapper)
        ├── bottomMainPanel/           ← À SUPPRIMER (wrapper)
        │   ├── SelectionPanel.qml + qmldir (module bottomMainPanel)
        │   ├── menuSelectionPanel/    (MenuSelector*, module menuSelectionPanel)
        │   │   └── moduleManager/     (ModuleManager*, PAS de qmldir propre)
        │   ├── assetSelectionPanel/   (+ playerConfigPanel/, screenEffectPanel/)
        │   ├── caseSelectionPanel/    (+ caseSelectionPanelMain/)
        │   ├── zonePanel/
        │   ├── templatePanel/
        │   └── editorBottomPanel/
        └── bottomSidePanel/           ← À SUPPRIMER (renommé configPanel)
            ├── BottomSidePanel.qml, BottomSidePanel_Content.qml, ModelSelectionPanel.qml + qmldir (module bottomSidePanel)
            ├── caseConfigPanel/
            ├── connectionConfigPanel/
            ├── visualEffectPanel/
            ├── zoneConfigPanel/
            └── sidePanel/             (MORT — qmldir seul, .qml absents)
```

### 1.2 Câblage actuel des panels

- **`SelectionPanel.qml`** (`module bottomMainPanel`) est le conteneur du « bas »
  instancié dans `Editor.qml`. Il contient :
  - `MenuSelector { id: topToolbar }` — **l'ancien sélecteur de menu** (barre au-dessus
    du panel) qui pilote `root.currentPanelIndex` via `onButtonClicked`.
  - un `StackLayout { currentIndex: root.currentPanelIndex }` qui ne contient
    aujourd'hui **qu'un seul enfant** : `AssetSelectionPanel`. (La sélection de cases /
    template / zone / joueur est intégrée **dans** `AssetSelectionPanel` via des
    onglets internes — `currentView`, `currentTabIndex`, `selectedCaseType`, …).
  - À noter : `menuSelectorModel` (le `ListModel` qui alimentait les boutons de
    `MenuSelector`) est **vide** (commenté). Le sélecteur est donc déjà quasi inerte
    visuellement — son rôle est repris par le `ModuleManager`.
- **`BottomSidePanel.qml`** (`module bottomSidePanel`) est le panneau latéral de
  configuration (effets visuels, config case, config zone, connexions). Instancié
  dans `Editor.qml` comme `sidePanel`.
- **`ModuleManager.qml`** : barre horizontale en haut de l'éditeur (instanciée dans
  `Editor.qml`, `id: moduleManager`). Aujourd'hui le `+` ouvre un popup, les modules
  choisis s'ajoutent à un `ListModel` interne et émettent `moduleAdded(moduleId)` —
  **mais rien n'est branché** : `Editor.qml` se contente de `console.log`. Catalogue :
  `case`, `deco`, `zone`, `template`, `player`, `chat`, `config3d`.

### 1.3 Modules morts (à nettoyer au passage)

- `bottomSidePanel/sidePanel/qmldir` → `module sidePanel` référençant `SidePanel.qml`
  et `SidePanel_Content.qml` **qui n'existent pas**. Aucun importeur. → supprimer.
- `caseSelectionPanel/qmldir` déclare `CaseSelectionPanel 1.0 CaseSelectionPanel.qml`
  → le fichier `CaseSelectionPanel.qml` **n'existe pas** (référence pendante,
  inoffensive tant que `CaseSelectionPanel` n'est jamais instancié). → corriger la ligne.

### 1.4 Importeurs externes aux arbres déplacés

Seuls 3 fichiers hors de `bottomPanel/` réfèrent aux modules concernés :

- `qml/editor/Editor.qml` → `import editor` (utilise `ModuleManager`, `SelectionPanel`,
  `BottomSidePanel`) + `import playerConfigPanel`.
- `qml/editor/MenuMapAtStart.qml` → `import playerConfigPanel`.
- `qml/editor/logic/MouseLogic_Base.qml` → `import bottomMainPanel` : **vestigial**
  (le fichier accède au `SelectionPanel` par référence injectée `logic.selectionPanel`,
  jamais par instanciation du type). → l'import peut être retiré, ou laissé si le
  module `bottomMainPanel` survit. Comme `bottomMainPanel` disparaît, **retirer cet import**.

Tous les autres importeurs (`editorBottomPanel` ×11, `assetSelectionPanel` ×3,
`caseSelectionPanel` ×2, `zonePanel` ×2, `screenEffectPanel`, `playerConfigPanel`,
`caseSelectionPanelMain`, `caseConfigPanel`, `visualEffectPanel`, …) sont **internes**
aux arbres déplacés et bougent en bloc → leurs `import X` restent valides puisque les
noms de dossiers-modules sont conservés.

---

## 2. Cible

### 2.1 Arborescence cible

```
qml/editor/
├── Editor.qml
├── qmldir
├── MenuMapAtStart.qml
├── logic/MouseLogic_Base.qml          (import bottomMainPanel RETIRÉ)
├── panel/
│   └── mapInfoPanel/                  (INCHANGÉ)
├── moduleManager/                     ← NOUVEAU (déplacé + receveur des panels de sélection)
│   ├── ModuleManager.qml, ModuleManager_AddButton.qml, ModuleManager_AddPopup.qml
│   ├── qmldir                         (NOUVEAU — module moduleManager)
│   ├── SelectionPanel.qml             (depuis bottomMainPanel/)
│   ├── menuSelectionPanel/            (MenuSelector* — voir Q1)
│   ├── assetSelectionPanel/  (+ playerConfigPanel/, screenEffectPanel/)
│   ├── caseSelectionPanel/   (+ caseSelectionPanelMain/)
│   ├── zonePanel/
│   ├── templatePanel/
│   └── editorBottomPanel/
└── configPanel/                       ← NOUVEAU (ex-bottomSidePanel)
    ├── BottomSidePanel.qml, BottomSidePanel_Content.qml, ModelSelectionPanel.qml
    ├── qmldir                         (module bottomSidePanel — nom conservé, voir Q3)
    ├── caseConfigPanel/
    ├── connectionConfigPanel/
    ├── visualEffectPanel/
    └── zoneConfigPanel/
    (sidePanel/ supprimé)
```

> **Choix de structure :** on **conserve les sous-dossiers-modules** (`assetSelectionPanel/`,
> `caseSelectionPanel/`, …) en les reparentant sous `moduleManager/`, plutôt que d'aplatir
> 60+ fichiers dans un seul dossier. C'est ce que signifie « ramener les fichiers enfants
> asset/case/… dans moduleManager » sans détruire la modularité interne. (Voir Q2 si une
> mise à plat totale est réellement souhaitée.)

### 2.2 `addImportPath` cibles (`cpp/qmlapp.cpp`)

```cpp
addImportPath("qrc:/qml");
addImportPath("qrc:/qml/editor");                         // module editor
addImportPath("qrc:/qml/editor/panel");                   // mapInfoPanel
addImportPath("qrc:/qml/editor/panel/mapInfoPanel");      // mapInfoPanelMain
addImportPath("qrc:/qml/editor/moduleManager");           // assetSelectionPanel, caseSelectionPanel,
                                                          //   editorBottomPanel, menuSelectionPanel,
                                                          //   zonePanel, templatePanel, SelectionPanel(bottomMainPanel? voir Q4)
addImportPath("qrc:/qml/editor/moduleManager/caseSelectionPanel");   // caseSelectionPanelMain
addImportPath("qrc:/qml/editor/moduleManager/assetSelectionPanel");  // playerConfigPanel, screenEffectPanel
addImportPath("qrc:/qml/editor/configPanel");             // caseConfigPanel, connectionConfigPanel,
                                                          //   visualEffectPanel, zoneConfigPanel, bottomSidePanel
```

(Suppression des entrées `…/bottomPanel`, `…/bottomMainPanel`, `…/bottomSidePanel`.)

---

## 3. Étapes d'implémentation

> Exécuter dans l'ordre. Après chaque grande étape : **build + lancement de
> l'éditeur** (cf. CLAUDE.md « Build Commands »). Pas de runner de test auto →
> validation manuelle. Aucun test ne couvre ce câblage, donc **chaque étape doit
> être vérifiée à l'œil** (l'éditeur charge, les panels s'affichent).

### Étape A — Préliminaire : déplacer `moduleManager` sous `editor/` (PREMIER)

1. `git mv qml/editor/panel/bottomPanel/bottomMainPanel/menuSelectionPanel/moduleManager qml/editor/moduleManager`.
2. Créer `qml/editor/moduleManager/qmldir` :
   ```
   module moduleManager
   ModuleManager 1.0 ModuleManager.qml
   ModuleManager_AddButton 1.0 ModuleManager_AddButton.qml
   ModuleManager_AddPopup 1.0 ModuleManager_AddPopup.qml
   ```
   (Aujourd'hui `moduleManager/` n'a pas de qmldir : `ModuleManager` est résolu
   uniquement via `editor/qmldir`. Lui donner son propre module le rend autonome.)
3. `qml.qrc` : mettre à jour les 3 `<file>` `…/moduleManager/ModuleManager*.qml`
   → `qml/editor/moduleManager/…` ; ajouter `qml/editor/moduleManager/qmldir`.
4. `qml/editor/qmldir` : `ModuleManager 1.0 moduleManager/ModuleManager.qml`.
5. `cpp/qmlapp.cpp` : ajouter `addImportPath("qrc:/qml/editor/moduleManager")`.
6. **Build + run** → l'éditeur charge, la barre `ModuleManager` s'affiche identique.

### Étape B — Déplacer les panels de sélection dans `moduleManager/`

1. `git mv` des sous-dossiers depuis `bottomMainPanel/` vers `moduleManager/` :
   `assetSelectionPanel`, `caseSelectionPanel`, `zonePanel`, `templatePanel`,
   `editorBottomPanel`, `menuSelectionPanel` (sans son ex-sous-dossier `moduleManager`,
   déjà sorti à l'étape A).
2. `git mv qml/editor/panel/bottomPanel/bottomMainPanel/SelectionPanel.qml qml/editor/moduleManager/SelectionPanel.qml`.
   Idem son `qmldir` (`module bottomMainPanel`) → décision Q4 (renommer `module moduleManager`
   et fusionner avec le qmldir de l'étape A, **ou** garder un `module bottomMainPanel`
   distinct). **Recommandé :** fusionner — `SelectionPanel` rejoint `module moduleManager`,
   et on supprime le module `bottomMainPanel`.
3. Supprimer les dossiers vides `bottomMainPanel/` puis `bottomPanel/` (une fois
   `bottomSidePanel` aussi déplacé, étape C).
4. `qml.qrc` : réécrire tous les chemins `…/bottomPanel/bottomMainPanel/…`
   → `…/editor/moduleManager/…` (≈ 45 entrées).
5. `cpp/qmlapp.cpp` : remplacer les import paths `…/bottomMainPanel`,
   `…/bottomMainPanel/caseSelectionPanel`, `…/bottomMainPanel/assetSelectionPanel`
   par leurs équivalents `…/moduleManager/…`.
6. `qml/editor/qmldir` : mettre à jour les chemins relatifs `SelectionPanel`,
   `ModuleManager` (déjà fait en A), et les ré-exports `…/bottomMainPanel/…` éventuels.
7. `qml/editor/logic/MouseLogic_Base.qml` : retirer `import bottomMainPanel` (vestigial).
8. Corriger la référence pendante `caseSelectionPanel/qmldir` (`CaseSelectionPanel.qml`
   inexistant) : supprimer cette ligne.
9. **Build + run** → vérifier que asset/case/template/zone s'affichent comme avant.

### Étape C — Déplacer `bottomSidePanel/` → `editor/configPanel/`

1. `git mv qml/editor/panel/bottomPanel/bottomSidePanel qml/editor/configPanel`.
2. Supprimer `configPanel/sidePanel/` (module mort).
3. `qmldir` de `configPanel/` : garder `module bottomSidePanel` (Q3) **ou** renommer
   `module configPanel` (impacte `editor/qmldir` + l'`import` éventuel ; aucun fichier
   ne fait `import bottomSidePanel` aujourd'hui → renommage à faible risque).
4. `qml.qrc` : réécrire les chemins `…/bottomPanel/bottomSidePanel/…`
   → `…/editor/configPanel/…` ; retirer les entrées `sidePanel`.
5. `cpp/qmlapp.cpp` : `…/bottomSidePanel` → `…/configPanel`.
6. `qml/editor/qmldir` : mettre à jour `BottomSidePanel`, `VisualEffectsPanel`,
   `CaseConfigurationPanelSection`, `ConnectionsConfigurationSection`,
   `ZoneConfigurationPanelSection` (chemins `panel/bottomPanel/bottomSidePanel/…`
   → `configPanel/…`).
7. Supprimer le dossier `bottomPanel/` désormais vide.
8. **Build + run** → vérifier le panneau latéral (effets, config case/zone, connexions).

> 💡 Étapes B et C peuvent être faites dans un seul commit « move » si on est à
> l'aise, mais les séparer facilite le diagnostic en cas de panel non résolu.

### Étape D — Câblage fonctionnel : `ModuleManager`, seul maître de l'affichage

> **Décisions verrouillées (2026-06-17, cf. §6) :**
> - Barre **vide** au départ ; modules ajoutés via `+`. Panneau **replié** tant
>   qu'aucune vignette n'est cliquée ; **re-clic** sur la vignette active = repli.
> - **Un seul panneau visible à la fois**, piloté **uniquement** par le ModuleManager.
> - **Suppression totale** de la mécanique d'onglets (`ASP_TitleBar` boutons +
>   `stackView` de bascule dans `AssetSelectionPanel`) et du sous-dossier
>   `menuSelectionPanel/` (MenuSelector*).
> - **Suppression des flèches ▼ (replier) / ▶ (panneau latéral).**
> - **Chaque module = un conteneur bespoke autonome** (pas de base partagée), qui
>   héberge le contenu existant **sans** `EditorBottomPanel`.
> - **Le `configPanel` (ex-side panel) devient un module à part entière** avec son
>   propre conteneur, sélectionnable via une vignette comme les autres.
> - `chat` → ouvre le `ChatDrawer` ; `config3d` → placeholder (log), panneau à venir.

Mapping module → panneau cible :

| `moduleId` | Conteneur bespoke (cible) | Contenu réutilisé |
|---|---|---|
| `deco` | `DecoPanel` (bas) | `ASP_ContentArea` |
| `case` | `CasePanel` (bas) | `CSP_ContentArea` |
| `zone` | `ZonePanel` (bas) | `ZP_Content` |
| `template` | `TemplatePanel` (bas) | `TP_Content` |
| `player` | `PlayerPanel` (bas) | `PCP_Content` |
| `config` | `ConfigPanel` (latéral) | contenu de `configPanel/` (effets, case, zone, connexions) |
| `chat` | — | `ChatDrawer.open()` |
| `config3d` | — | placeholder (log) |

Sous-étapes (chacune = un push validable) :

- **D1** — `ModuleManager` rendu interactif : `property string selectedModuleId`,
  signal `moduleSelected(id)`, `toggleModule(id)` (re-clic = désélection → `""`),
  highlight de la vignette active (bordure `Theme.accent`), ajout du module `config`
  au catalogue. *Aucun consommateur encore → pas de bascule de panneau, juste
  l'interaction.* (FAIT.)
- **D2** — Hôte d'affichage : `SelectionPanel` (ou un nouvel hôte) n'affiche qu'**un**
  conteneur de module à la fois selon `moduleManager.selectedModuleId`
  (`Loader`/`StackLayout` clé = module), replié si `""`. `Editor.qml` route
  `onModuleSelected` (bas → hôte bas ; `config` → hôte latéral ; `chat` → drawer ;
  `config3d` → log).
- **D3** — Individualisation : créer les conteneurs bespoke `DecoPanel`/`CasePanel`/
  `ZonePanel`/`TemplatePanel`/`PlayerPanel`/`ConfigPanel`, chacun hébergeant son
  contenu existant **sans** `EditorBottomPanel` ni barre d'onglets.
- **D4** — Démantèlement : suppression de `menuSelectionPanel/` (MenuSelector*),
  retrait des boutons d'onglets de `ASP_TitleBar` + du `stackView` de bascule dans
  `AssetSelectionPanel`, suppression des flèches ▼/▶.
- **D5** — `chat` → `ChatDrawer.open()` ; `config3d` → placeholder (log).

Après chaque sous-étape : **build + run** ; vérifier qu'un seul panneau s'affiche et
que re-cliquer la vignette active le referme.

---

## 4. Checklist de cohérence (anti-régression)

À cocher après les déplacements, **avant** le câblage D :

- [ ] `qml.qrc` : aucun `<file>` ne pointe encore vers `bottomPanel/` (grep).
- [ ] `cpp/qmlapp.cpp` : plus aucun `addImportPath` vers `bottomPanel`/`bottomMainPanel`/`bottomSidePanel`.
- [ ] `qml/editor/qmldir` : tous les chemins relatifs résolvent vers des fichiers existants.
- [ ] `grep -rn "bottomPanel\|bottomMainPanel\|bottomSidePanel" qml cpp CMakeLists.txt`
      → ne reste que d'éventuels `module bottomMainPanel`/`bottomSidePanel` conservés volontairement.
- [ ] `CMakeLists.txt` ligne ~155 (`QML_IMPORT_PATH … bottomSidePanel/`) → mettre à jour
      vers `configPanel/` (sinon le code model Qt Creator perd les types ; n'affecte pas le runtime).
- [ ] Tous les `import X` (noms de modules) inchangés et résolvables.
- [ ] Éditeur lance sans erreur console `module "X" is not installed` / `Type Y unavailable`.
- [ ] Les 3 importeurs externes (§1.4) compilent : `Editor.qml`, `MenuMapAtStart.qml`, `MouseLogic_Base.qml`.

---

## 5. Risques & points d'attention

- **Résolution d'import silencieuse.** Un dossier-module non couvert par un
  `addImportPath` → `module "X" is not installed` au runtime (pas au build, le QML
  n'est pas compilé statiquement ici). D'où la vérification « build + run » après chaque étape.
- **`editor/qmldir` est le maillon fragile** : ses chemins relatifs ne sont pas vérifiés
  au build. Une faute = type indisponible à l'exécution seulement.
- **`git mv` vs qrc.** Le `git mv` ne touche pas `qml.qrc` ni `qmlapp.cpp` : ces deux
  fichiers doivent être édités à la main en parallèle.
- **Build Windows uniquement** (Qt 6.11 + MinGW, cf. CLAUDE.md). La validation finale
  doit être faite côté Valou/Windows ; impossible de builder/lancer sur cet environnement Linux.
- **Collab/automation hooks.** `editorAutomationHooks` (dans `Editor.qml`) appelle
  `placeAsset`/`placeCase` via le chemin UI ; vérifier qu'ils ne dépendent pas d'un
  `currentPanelIndex` figé après le câblage D.
- **`MenuSelector` partiellement vivant.** Même si son `ListModel` est vide, il porte
  les boutons expand (▼/▶) et le redimensionnement — ne pas le supprimer sans replacer
  ces contrôles (Q1).

---

## 6. Questions — tranchées

- **Q1 — `MenuSelector`** : ✅ **retiré** (sous-dossier `menuSelectionPanel/` supprimé en D4).
  Le ModuleManager devient l'unique sélecteur.
- **Q2 — Aplatissement** : ✅ sous-dossiers-modules **conservés** sous `moduleManager/`.
- **Q3 — Nom du module config** : ✅ renommé `module configPanel` (étape C, fait).
- **Q4 — `SelectionPanel`/`bottomMainPanel`** : ✅ fusionné dans `module moduleManager`,
  `bottomMainPanel` supprimé (étape B, fait).
- **Q5 — chat / config3d** : ✅ `chat` → `ChatDrawer.open()` ; `config3d` → placeholder (log).
- **Q6 — État initial** : ✅ barre **vide** + ajout via `+` ; panneau **replié** jusqu'au
  premier clic de vignette ; re-clic = repli.
- **Q7 — Persistance** : ⏳ **reportée** (non couverte par cette itération — les modules
  ajoutés ne survivent pas au redémarrage pour l'instant).
- **Q8 — Conteneurs** : ✅ **bespoke complet par module** (pas de base partagée), sans
  `EditorBottomPanel`. Le `configPanel` (ex-side panel) devient un module ; **flèches ▼/▶
  supprimées**.

---

## 7. Découpage en commits suggéré

1. `refactor(editor): moduleManager remonté sous editor/ (+ qmldir propre)` — étape A.
2. `refactor(editor): panels de sélection regroupés sous moduleManager/, bottomMainPanel supprimé` — étape B.
3. `refactor(editor): bottomSidePanel → editor/configPanel, sidePanel mort supprimé` — étape C.
4. `feat(editor): ModuleManager pilote l'affichage d'un panel unique` — étape D.

Chaque commit doit laisser l'éditeur **fonctionnel** (build + run OK).
