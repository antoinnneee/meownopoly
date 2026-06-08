# L'Histoire de Meownopoly

> Du premier commit au P2P : chronique d'un Monopoly de chats forge a deux, commit par commit.
> Document verifie par analyse des diffs reels de chaque commit.

---

## En chiffres

| Indicateur | Valeur |
|---|---|
| Premier commit | 31 janvier 2025 |
| Commits totaux | **1 092** |
| Developpeurs | **Antoine** (antoinnneee) ~642 commits, **Valere** (Valere21) ~450 commits |
| Pic d'activite | Aout 2025 (193 commits) |
| Branches principales | `V2`, `V2Antoine`, `V2_Valou`, `main` |
| Stack technique | Qt6 / QML / C++20, Node.js (serveurs), CMake + Ninja |
| Lignes touchees | ~1.58M ajoutees, ~1.63M supprimees (refactoring intensif) |

### Rythme de travail

```
Commits par mois :
Jan 25  |#                                          1
Mar 25  |##                                         6
Jul 25  |############################               99
Aou 25  |#############################################  193  <- pic
Sep 25  |#####################################      145
Oct 25  |########################################   160
Nov 25  |######################                     84
Dec 25  |##############################             114
Jan 26  |#################                          64
Fev 26  |######################################     147
Mar 26  |##################                         68
Avr 26  |###                                        11
```

Les sessions ont lieu principalement **le soir (18h-23h)** et **le week-end** (samedi + dimanche = 42% des commits). Le projet est clairement un side-project de passion, travaille apres les cours/le boulot et les jours de repos.

---

## Chapitre 1 : La Genese — V1 (Janvier - Mars 2025)

**Commit fondateur** : `9b15cf6` — *"first commit"* — 31 janvier 2025, 19h50.

Antoine pose les fondations seul. Le projet demarre avec un fichier `.pro` (qmake), une structure C++ a plat (pas de sous-dossier `cpp/`).

### Ce que contient le premier commit

Le chargeur de jeu est un parseur CSV naif mais fonctionnel :

```cpp
void Game::init_caseFile() {
    QFile caseFile(CASE_FILE_PATH);  // ":/config/cases.csv"
    QList<QByteArray> caseInfo = caseFile.readAll().split('\n');
    int line = 1;  // skip header
    while (line < caseInfo.count()) {
        QList<QByteArray> caseInfoLine = caseInfo.at(line).split(',');
        switch (type) {
            case CT_RestArea: { /* seul cas gere */ }
            default: qDebug() << "type unknow" << caseInfoLine;
        }
    }
}
```

Le CSV initial contient seulement 4 cases avec 10 colonnes : `Type, Name, Famille, price1..price6, homePrice, HotelPrice`. L'enum `CaseType` definit deja tout le vocabulaire felin : `CT_KibbleDispenser` (depart), `CT_RestArea` (terrain), `CT_CatDoor` (gare), `CT_Jail`, `CT_ToJail`, `CT_FreeNap` (parking gratuit), `CT_CatNip`, `CT_CardBoardBox`.

`CaseRestArea` gere deja l'ownership (`Player *m_owner`) et un tableau de prix par qualite de repos (`RQ_NONE` -> `RQ_HOTEL`). `CaseStart` et `Game` sont des squelettes. `game.cpp` ne fait qu'afficher "HelloWorld" dans `debugButton()`.

Le commit inclut aussi un framework de tests maison (`test/suite.cpp`), un `crashReportTool.cpp` (handler `SIGSEGV`/`SIGFPE`), et une collection complete de composants QML stylises (`AppButton`, `AppSlider`, `AppColorPicker`, `AppCircleProgressBar`...) — manifestement recuperes d'un projet precedent.

### L'IA arrive tres tot (1er mars 2025)

Le commit `d12e71a` (*"ai update"*) est surprenant : des le deuxieme commit, une integration **Ollama** complete est ajoutee. C'est 211 lignes d'un vrai client HTTP Qt vers un LLM local.

**Objectif** : traduire automatiquement les textes du jeu. Le prompt envoye :

```cpp
QString prompt = QString(
    "traduit en %1 uniquement les champs nommes \"text\", "
    "repond uniquement avec le tableau json sans rien ajouter d'autre : %2")
    .arg(targetLang, jsonString);
// Parametres : "stream": false, "temperature": 1.5 (tres elevee)
```

`JSON_AI_lang` gerait la serialisation des paires `(cle, texte)` et `OllamaTranslator` le client HTTP. Simultanement, le CSV passe de 4 a **38 cases** — le plateau complet, probablement genere avec l'aide d'un LLM (noms anglais : "Cozy Corner", "Sunny Spot", "Windowsill", "Cat Tower"...).

### Mars 2025 : les premieres vraies vues

Le commit *"gameplay ?"* (17 mars) ajoute +2 500 lignes de QML : `BoardGrid.qml`, `BoardTile.qml` (460 lignes avec couleurs par famille et emojis de fallback), `ControlPanel.qml`, `GameBoard.qml`, `PlayerSetup.qml`. `BoardTile.qml` definissait :

```qml
property var fallbackIcons: [
    "cat_money",   // 0: Kibble Dispenser
    "bed",         // 1: Rest Area
    "package_question", // 2: Card Board Box
    // ...
]
```

En une nuit (17-18 mars), `AnimatedPlayerToken.qml` nait — 207 lignes, puis 587 lignes le lendemain matin — pion joueur anime avec `PathAnimation` Qt. Le 18 mars a 9h : *"some feature broke on cleaning"* — un commit de nettoyage qui casse des fonctionnalites. L'habitude est posee.

**Etat V1** : un prototype solo avec CSV, QML generatif, integration Ollama experimentale, framework de tests inutilise.

---

## Chapitre 2 : The Purge — Naissance de la V2 (Juillet 2025)

> *"euhhhh"* — Antoine, 13 juillet 2025, en redecouvrant le code apres 4 mois

### Le grand retour (13 juillet)

Apres 4 mois de silence total, commit `45c4193` (*"euhhhh"*) : +2 206 lignes de QML. Refonte complete de l'UI avec 9 nouveaux fichiers : `CompactDiceControl.qml`, `DiceBase.qml`, `DicePanel.qml`, `GameActionButton.qml`, `GameActionDialog.qml`, `PlayerTurnPanel.qml`, `PropertyController.qml`, `PropertyPurchasePanel.qml`, `TurnManager.qml`.

La logique de `Player::move()` est centralisee : passage par la case depart (200 kibbles), signal `passedStart()`, appel `currentCase->onLand(this)`. `GameBoard.qml` gagne une gestion d'etat anti-race condition :

```qml
property bool isHandlingPlayerMovement: false
property bool isCheckingProperties: false
// + timers de securite 3s pour debloquer les flags coinces
```

### "The Purge !!!" (14 juillet, 13h32)

Le lendemain, `d985a0f` : **-735 lignes, +9 lignes**. Ce qui est purge :

| Fichier supprime | Contenu | Lignes |
|---|---|---|
| `ollamatranslator.cpp/h` | Client Ollama LLM | 211+68 |
| `json_ai_lang.cpp/h` | Serialisation pour l'IA | 133 |
| `test/suite.cpp/h` + `testMain.cpp` | Framework de tests maison | 140 |
| `crashReportTool.cpp/h` | Handler de crash SIGSEGV | 119 |

Correction discrète : dans `debug_info.h`, les sequences ANSI etaient cassees depuis le debut (`"033[31m"` -> `"\033[31m"` — le `\` manquait).

La purge supprime ce qui avait ete "copie-colle pour voir" sans jamais etre integre : l'IA, les tests, le crash handler. Ca precede de quelques heures l'arrivee de Valere.

### Valere entre en scene

Le 14 juillet a 17h08, commit `93c4513` signe l'arrivee de **Valere21** avec un sobre *"zo"*. Ils mettent en place le workflow de branches (V2/V2Antoine/V2_Valou) et commencent a travailler en parallele.

**14 juillet apres-midi — commit `72e6edc` ("valou V2")** : Valere cree immediatement deux classes fondamentales :
- **`CaseCatDevice.h/.cpp`** : case "appareil electronique" (equivalent des compagnies de service)
- **`CaseCatPerks.h/.cpp`** : classe abstraite mixin pour les cases achetables — contient `buyCase()`, `sellCase()`, `m_price`, `m_sell`, `Player* owner`

En parallele, Antoine ajoute dans `Player` la gestion des `QList<CaseCatDevice*>` et `QList<CaseCatDoor*>`, et le commit *"clean project"* simplifie la hierarchie : `CaseFreeNap` migre `m_poolMoney` vers `m_kibbleAmount`, l'enum `CaseType` fusionne `CT_GoldenCollar` et `CT_FurTax` en `CT_Taxe`.

### La semaine de feu (14-20 juillet)

**15-16 juillet — Valere pose les joueurs** :
- `Game::initPlayers()` genere des joueurs accessibles en QML via `Q_PROPERTY QList<Player*> listPlayers`
- `Player` expose nom, kibble, position, `isInJail` via `Q_PROPERTY`
- `TEST_VIEW_3.qml` : premiere vue qui affiche les joueurs crees dynamiquement en C++

**18 juillet — Commit majeur : le chargement JSON remplace le CSV** :
Valere cree `config/cases.json` (643 lignes, 40 cases) et implemente `Game::initCases()` :
- Factory `getCase(QStringList)` instancie le bon sous-type selon un entier `type` (0-9)
- `FamilyType` enum pour les groupes de couleur
- Loyers stockes en `QList<int>` (6 paliers : 0 maison jusqu'a hotel)
- Ajout de `Case::intToCaseType(int)` pour la deserialisation

Le meme jour, Antoine explose la couche QML des tuiles (+1 611 lignes) : `CaseTile.qml`, `TileContent.qml` (dispatch dynamique), `TileDetailsPopup.qml`, `AnimatedPlayerToken.qml` (640 lignes !), et le repertoire `details/` avec un composant par type de case. Il ecrit aussi `INHERITANCE_QML.md` pour documenter le pattern d'heritage.

**19 juillet** : `CaseStart` est supprime et remplace par `CaseKibbleDispenser` (distributeur de croquettes = case depart). Les composants QML passent de `tileData` (generique) a `caseData` (type `Case*`). `Game::createNewCase()` expose en `Q_INVOKABLE` pour instanciation depuis QML.

**20 juillet** : *"Cases generation full"* — Valere unifie la generation : `TEST_BOARD.qml` n'affiche plus qu'une boucle sur `Game.listCases()`, tout est cree en C++.

### Structure de donnees du plateau : la liste chainee (23 juillet)

Commit architectural majeur de Valere : `Case` acquiert une **liste chainee doublement liee avec branches multiples** :

```cpp
class Case {
    QList<Case*> next;  // successeurs (branches multiples possibles)
    QList<Case*> prev;  // predecesseurs
    Case* getNext(int index);
    void addNext(Case*);
    void removeNext(Case*);
    // idem pour prev
};
```

Cela permet des plateaux non-lineaires (embranchements, raccourcis). `Game::m_listCases` passe de `QList<Case*>` a `Case**` (pointeur vers la tete de la liste chainee). Note du commit : *"Need to remove Game.listCase[index] in QML"* — conscient que l'acces indexe QML doit etre adapte.

### Debut de l'editeur (23 juillet)

Antoine pose le premier embryon : `Editor.qml` avec `GridManager`, `SnapableElement`, `MapTileElement`, et `GridControlPanel.qml` (toggle grille, taille, snap). Les tuiles supportent les types `wall`, `door`, `spawn`, `floor`, `item`.

### Le game design V2 (27 juillet)

Commit *"add nreame"* : `README.md` (134 lignes) formalise les mecaniques :
- **Coproprietes** : parts fractionnees (propriete partagee)
- **Peages a mi-parcours** : loyer meme en survol
- **Encheres anonymes** : la mise la plus basse est revelee
- **4 phases de tour** : action pre-deplacement, deplacement (relance exponentielle), action post-deplacement, attente
- **Personnages** avec modificateurs de des

**Etat du projet** : un jeu avec hierarchie de cases complete, chargement JSON, plateau en liste chainee, debut d'editeur, game design formalise.

---

## Chapitre 3 : L'Editeur Prend Forme (Aout 2025)

Aout est le mois le plus prolifique (193 commits). L'editeur de cartes nait en 4 semaines.

### Le systeme SnapableElement / ItemSnapable

**8 aout — Valere pose la structure C++** :
`ItemSnapable` herite de `QObject` avec `unitSizeWidth`, `unitSizeHeight`, `gridRelativePosition`, `zLayer`, `QUrl assetUrl`, et une liste chainee `next`/`prev`. Deux sous-classes : `SnapableCase` (contient `Case *caseCurrent`) et `SnapableDeco`.

**25 aout — Antoine refactore en profondeur** :
Les parametres d'affichage sont extraits dans une classe dediee :

```cpp
class DisplayParameter : public QObject {
    Q_PROPERTY(int unitSizeWidth ...)
    Q_PROPERTY(int unitSizeHeight ...)
    Q_PROPERTY(int gridRelativePosition ...)
    Q_PROPERTY(int zLayer ...)
    DisplayParameter(const QJsonDocument &json, QObject *parent = nullptr);
    QString toJSON();
};

class ItemSnapable : public QObject {
    ItemSnapable(Case*, DisplayParameter*, QObject*);
    ItemSnapable(const QJsonDocument &json);  // deserialisation directe
    Q_INVOKABLE QString toJSON();
    Case *m_caseData;
    DisplayParameter *m_displayParameter;
};
```

Le meme jour, Valere ajoute `QUuid::createUuid()` pour les identifiants (remplacement des `int`), et cree la classe `Decoration` separee avec son propre `DecorationType` enum.

### Architecture de l'editeur

**3 aout** : `GridManager` avec signal `onGridPressed(position)` declenchant un menu contextuel. Touches 1/2/3 et PageUp/PageDown pilotent le z-layer.

**9 aout — Visualisation des connexions** :
Deux approches testees le meme jour :
1. `ConnectionOverlay.qml` : `Rectangle` oriente via `Math.atan2`, gradient rouge -> bleu
2. `ConnectionOverlay2.qml` : `QtQuick.Shapes` + `ShapePath` (trace vectoriel)

**10 aout** : la connexion migre dans `SnapableElementConnections.qml` — chaque tile gere ses propres segments via un `Repeater` local. Plus besoin de rebuild global depuis `Editor.qml`.

**24 aout — Refactoring majeur** :
`Editor.qml` (-338 lignes) se scinde en :
- **`EditorLogic.qml`** (`QtObject`) : `snapableTilesList`, `currentSelectedElement`, `nextTileId`, fonctions `deselectAllTiles()`, `deleteElement()`, `createNewTileAtPosition()`
- **`EditorDynamicComponent.qml`** : deux `Component {}` pour `SnapableCaseTile` et `SnapableDecoration`, avec wiring complet vers les panneaux

### Le systeme d'assets

**19 aout** : serveur Node.js dans `asset_server/` (305 lignes) avec endpoints `/api/ping`, `/api/version`, `/api/download/:version`. Cote C++, `LauncherManager` singleton :

```cpp
class LauncherManager : public QObject {
    Q_PROPERTY(QString currentVersion ...)
    Q_PROPERTY(bool isDownloading ...)
    Q_PROPERTY(double downloadProgress ...)
    Q_INVOKABLE void testServerConnection(const QString &serverUrl);
    Q_INVOKABLE void checkForUpdates(const QString &serverUrl);
    Q_INVOKABLE void downloadResources(const QString &serverUrl, const QString &version);
    Q_INVOKABLE void createResourcePackage(const QString &folderPath, const QString &version);
    signal void logMessage(const QString &message);
};
```

Les paquets d'assets sont des `.meow` (zips renommes via `FolderCompressor`/QtFolderCompressor).

**20 aout** : creation du vrai `AssetManager` avec cache :

```cpp
class AssetModel : public QAbstractListModel {
    enum AssetRoles { PathRole, TypeRole, CategoryRole, RatioRole,
                      WidthRole, HeightRole, IdRole, FilenameRole };
    Q_INVOKABLE AssetModel* createFilteredModel(const QString &type) const;
};

class AssetManager : public QObject {
    Q_PROPERTY(AssetModel* decorationModel ...)
    Q_PROPERTY(AssetModel* playerIconModel ...)
    Q_INVOKABLE AssetModel* getTypeModel(const QString &category, const QString &type);
    mutable QHash<QString, AssetModel*> m_filteredModels;  // cache
};
```

Assets charges depuis `asset_extracted/` via des fichiers `metadata.json` par sous-dossier.

### Le Launcher

6 fichiers QML crees dans `qml/launcher/` : `Launcher.qml`, `LauncherLogic.qml`, `ActionsSection.qml`, `LogsSection.qml`, `ServerConfigSection.qml`, `PackagingSection.qml`. URL par defaut : `pattounecorp.ovh` (serveur perso d'Antoine, ajoute le 21 aout).

### Sauvegarde JSON

**24 aout** : `Case::toJSON()` est ajoute en methode virtuelle. Format :
```json
{ "name": "...", "uniqueId": "uuid", "type": 5, "next": ["uuid1"], "prev": ["uuid0"] }
```
Chaque sous-classe surcharge `toJSON()` en ajoutant ses champs specifiques (`price`, `houseRent`, `maxHouse`...).

**27 aout** : creation de `Map` et `MapLoader` :

```cpp
class Map : public QObject {
    Q_PROPERTY(QList<ItemSnapable*> caseTiles ...)
    Q_PROPERTY(QList<ItemSnapable*> decorationTiles ...)
    Map(QJsonObject jsonObject, QObject *parent);  // charge depuis JSON
};

class MapLoader : public QObject {  // singleton QML
    Q_INVOKABLE Map *loadMap(QString mapName);
    signal void foundCaseTile(DisplayParameter*, Case*);
};
```

`Map::Map(QJsonObject)` fait deux passes : construction des `ItemSnapable`, puis resolution des liens `next`/`prev` par UUID.

### Effets visuels

**27 aout** : `VisualEffectsPanel.qml` (668 lignes) avec controles pour brightness, contrast, saturation, colorization, blur, shadow, rotation, mirror — appliques via `QtQuick.Effects`.

### Journee marathon du 24 aout

20+ commits entre 11h et 23h. Les deux devs mergent intensivement. L'editeur passe d'un prototype a un outil fonctionnel en une journee. Antoine fixe le plan slider, le control panel, le layer vizu ; Valere ajoute `mapName`, `saveMap()`, les UUID.

**Etat du projet** : editeur avec grille, placement d'elements, connexions, sauvegarde JSON, assets distants, launcher.

---

## Chapitre 4 : L'UX de l'Editeur (Septembre 2025)

Le focus se deplace vers l'experience utilisateur.

### Le systeme MouseLogic

**6 septembre** : `EditorLogic.qml` recoit `editorMouseMode` (`EM_NORMAL` / `EM_POSE`). La logique souris etait inline (~80 lignes dans le `MouseArea` principal).

**9 septembre — Extraction en composants** :
Trois fichiers QML dans `qml/editor/logic/` :

- **`MouseLogic_Base.qml`** : `QtObject` avec `list<SnapableElement> clickElement`, `clickPosition`, `elementInitialPosition`. Definit les fonctions polymorphiques : `pressedLeft`, `pressedRight`, `pressedMiddle`, `release`, `pressedAndHold`, `clicked`.

- **`MouseLogic_Selection.qml`** (herite de `Base`) : sur `pressedLeft` avec elements, transfere dans `groupeSelection` et assigne `drag.target`. Sur `pressedRight`, panoramique (`drag.target = editorGrid`). Supporte `Qt.ControlModifier` pour ajout a la selection sans deselecter.

- **`MouseLogic_Pose.qml`** (herite de `Base`) : sur `clicked`, appelle `placeSelectedAsset(gridPos)`. Sur `pressedRight`, efface la selection d'asset.

Le chargement est dynamique via `Loader` :
```qml
Loader {
    sourceComponent: (logic.editorMouseMode == EditorEnum.EM_NORMAL)
        ? mouseLogic_selection_comp : mouseLogic_pose_comp
}
```

**10 septembre — Multi-selection** :
`MouseLogic_Selection` recoit une liste `selectedElements`. `unselectAllElements()` reinitialise le `groupeSelection`. La fonction `changeMouseMode(mode)` permet la transition interne entre modes.

### Selection par rectangle AABB

**2 octobre** : `MouseLogic_Selection` recoit `isRectangleSelecting: bool`, `rectangleStart: point`, `rectangleCurrent: point`. Un composant `SelectionRect.qml` est extrait avec methodes `show()`, `hide()`, `updateGeometry()`. `finalizeRectangleSelection()` calcule les elements dans le rectangle AABB via `getElementsInRectangle(start, current)`.

### Effets visuels

**4 septembre** : `effectsLocked: bool` dans `VisualEffectsPanel` + bouton verrou. `getCurrentEffects()` retourne un objet structure :
```js
{ brightness, contrast, saturation, colorization, colorizationColor,
  blurEnabled, blur, shadowEnabled, shadowBlur,
  rotationAngle, mirrorHorizontal, mirrorVertical }
```
Lors du placement, `applyVisualEffectsToNewTile(newTile)` verifie le verrou et ecrit chaque valeur dans `newTile.displaySettings`.

### Panneaux (Valere)

Valere refactore en profondeur — le 12 septembre il pousse *"C'est de la merde"* et enchaine avec 10 jours de refactoring massif :
- **CaseSelectionPanel** (CSP) : grille par categorie avec `CSP_Item` composant
- **MapSelectionPanel** (MSP) : settings avec icones, scrollbar, `MSP_SettingPanel`
- **MenuSelector** : composant reutilisable pour les barres d'outils
- Travail de 2h a 7h du matin (15 septembre) sur les panneaux

**Etat du projet** : editeur avec mouse logic modulaire, multi-selection, effets visuels verrouillables, panneaux modulaires.

---

## Chapitre 5 : Fonctionnalites Avancees (Octobre 2025)

### Le parcours technique des sprites animees

Valere tente d'ajouter les animations — les diffs revelent le cheminement :

1. **30 sept** : premiere tentative avec `AnimatedSprite` (Qt Quick) dans un `Loader`. Exige `frameWidth`, `frameHeight`, `frameCount`, `frameDuration` — recuperes depuis `AssetManager`.

2. **2 oct** : bug de transparence — `isTransparent()` referenceait `loaderImage.paintedHeight` au lieu de `loaderImage.item.paintedHeight`. Fix + guard `typeof loaderImage.item.paintedHeight === 'undefined'`.

3. **2 oct** : **changement d'approche** — abandon de `AnimatedSprite` au profit de `AnimatedImage` natif Qt. Supporte nativement `.gif` et `.webp` animes sans configuration de frames. La meme source fait office d'image statique ou animee selon le fichier.

4. **19 oct** : `AssetManager` C++ expose le chemin du fichier anime (`.webp`) a partir du chemin statique.

### CaseFactory

**10 octobre** : Valere refactore la hierarchie `Case`. Le `QUuid` est genere automatiquement dans le constructeur (plus passe en parametre).

```cpp
Case* CaseFactory::createCase(CaseType type) {
    switch(type) {
        case CS_RestArea: return new CaseRestArea(/*loyers*/ {50,100,200,300,400,5000});
        case CS_KibbleDispenser: return new CaseKibbleDispenser("test", 200);
        // ... tous les types
    }
}

void CaseFactory::registerCaseQml() {
    qmlRegisterUncreatableType<Case>(...);       // base abstraite
    qmlRegisterUncreatableType<CaseCatPerks>(...); // mixin
    qmlRegisterType<CaseRestArea>(...);          // types concrets
    // ...
}
```

### Systeme de liens entre elements

**10 octobre** : `ConnectionsConfigurationPanel` (679 lignes, fenetre flottante) est supprime et migre dans `ConnectionsConfigurationSection` a l'interieur du `CaseSelectionPanel`.

**12 octobre** : `MouseLogic_Selection_link.qml` (herite de `MouseLogic_Selection`) :
- Proprietes : `kind: ""` (valeurs `"previous"` / `"next"`), `linkSourceCase`
- Clic sur un autre element : `logic.tileLogic.createSnapableLink(linkSourceCase, clickElement[0], kind)`
- Clic sur la source elle-meme : retour au mode `EM_NORMAL`

```js
function createSnapableLink(source, target, kind) {
    if (kind === "previous") source.connectionManager.addPreviousElement(target)
    else if (kind === "next") source.connectionManager.addNextElement(target)
}
```

### Case config panels

Integration dans le flux de selection :
```js
// MouseLogic_Selection.updateCaseConfiguration():
if (selectedElements.length === 1 && element.caseData !== undefined)
    logic.selectionPanel.casePanel.csp_contentArea
        .caseConfigurationPanelSection.setTargetCase(element)
else
    configPanel.clearTarget()
```

### Pipeline image_tools

4 scripts Python crees :
- **`extraire_frames.py`** : extraction multi-thread de frames MP4 via OpenCV
- **`supprimer_fond.py`** : suppression de fond avec BiRefNet (GPU), BiRefNet_lite, RMBG-2.0, ou OpenCV en fallback
- **`creer_animation_webp.py`** : assemblage WebP anime via Pillow (FPS, qualite, loop)
- **`pipeline_mp4_vers_animation.py`** : orchestre les 3 en 7 etapes. Options `--use-lite`, `--double-pass` (deux passes de suppression de fond pour affiner les masques), `--use-rmbg`

### Autosave (debut)

**17 octobre** : `MapLoader` recoit enum `MapType { AUTOSAVE, CUSTOM }`. `MapInfo` ajoute `autosaveMapName` (defaut `"autosave_tmp"`). **28 octobre** : debounce cote QML avec `Timer { interval: 100 }` pour eviter les sauvegardes en rafale.

**Etat du projet** : editeur complet avec animations, liens, CaseFactory, config panels, pipeline d'assets, autosave basique.

---

## Chapitre 6 : Le Plateau de Jeu & Les Panneaux (Novembre 2025)

### Separation editeur / jeu

**1er novembre** : creation de `qml/board/` avec :

- **`GameBoard.qml`** : `Rectangle` encapsulant `GridManager`, `Background`, `TileLogic`, `GameDynamicComponent`. Ecoute les signaux `Game.onFoundItemSnapableTile` et `Game.onMapLoaded`. Contient un `MouseArea` qui delegue a `logic.mouseLogic` — architecture identique a l'editeur.

- **`GameDynamicComponent.qml`** : conteneur de deux `Component {}` (`snapableCaseTileComponent`, `snapableDecorationComponent`).

`Background.qml` migre de `qml/editor/` vers `qml/component/` pour etre partage. Les deux contextes partagent `TileLogic`, `GridManager`, `MouseLogic_Base` mais le `GameBoard` n'importe pas les panneaux d'edition.

### Undo/Redo v1 (UndoRedoManager)

**4 novembre** : la classe `UndoRedoManager` (singleton C++) gere un `QVector<QJsonObject> m_listEdits` avec un indice `m_currentEditIndex` :

- `onUpdateListEdits(QJsonObject)` : sauvegarde un etat. Si `m_isRestoringState == true`, sauvegarde bloquee. Si l'index est avant la fin, les etats futurs (redo) sont effaces.
- `onAskEdit(EditAction)` : `Preview` = Undo (decremente), `Next` = Redo (incremente)

**Bug critique resolu** : le flag `m_isRestoringState` etait remis a `false` immediatement apres `emit returnEdit(...)`, permettant des sauvegardes parasites pendant le rechargement asynchrone du JSON en QML. **Solution** : le QML appelle `Q_INVOKABLE clearRestorationFlag()` une fois le chargement termine.

### EditorSidePanel

`EditorSidePanel.qml` : `Rectangle` anime a droite de l'editeur.
- **Handle de redimensionnement** : `Rectangle` 10px en haut. Le `MouseArea` capture les coordonnees globales via `mapToItem(root.parent, ...)`, calcule un delta, modifie `root.width` / `root.x`.
- **Animations** : `Behavior on x` / `Behavior on height` avec `NumberAnimation` 300ms, `Easing.InOutQuad`

### Autosave par debounce (Valere)

Suppression de la sauvegarde sur modification au profit d'une sauvegarde reguliere (~500ms/1s). `Timer` avec `restart()` a chaque changement.

### Explorations Quick3D

**19 novembre** : integration d'une `View3D` superposee dans l'editeur. Scene 3D avec `DirectionalLight`, modele `PrincessV2` (`.glb`), `OrthographicCamera` inclinee (`eulerRotation.x: -55`) pour vue isometrique. La camera est positionnee dynamiquement selon la grille 2D. Le 22 novembre, le launcher recupere les modeles 3D via `AssetManager`.

**Etat du projet** : separation editeur/jeu, undo/redo, side panel, explorations 3D.

---

## Chapitre 7 : Le Moteur Physique PattounX (Decembre 2025)

> Le mois ou Antoine decide qu'un Monopoly a besoin d'un moteur physique.

### Evolution architecturale

Les diffs revelent une serie de renommages qui raconte l'evolution de la conception :

1. **29 nov** : creation de `ExclusionParameter` (zones d'exclusion sur la carte) avec `QVariantList m_polygonPoints`, `m_zoneColor`, `m_zoneName`
2. **16 dec** : renommage `ExclusionParameter` -> `PolygonParameter`
3. **21 dec** : renommage `PolygonParameter` -> `ZoneParameter`, fusion `ExclusionZone` + `EffectZone` -> `PhysicZoneTile`
4. **31 dec** : renommage global `physics2d_*` -> `pattounx_*` — le moteur a son nom

### Classes principales (etat final)

**`PattounX_body`** (ex-`PhysicsBody2D`) :

```cpp
// Q_PROPERTY exposees :
position, velocity, collisionRadius, bounceFactor, slideFactor,
acceleration, maxSpeed, mass, invMass, restitution,
staticFriction, dynamicFriction, linearDamping,
isStatic, collisionEnabled, isColliding, inputVector
```

Methode `integrate(dt)` : integration d'Euler semi-implicite — accumulation de forces, mise a jour de vitesse, damping exponentiel framerate-independant via `frictionFactor = pow(1.0 - linearDamping, dt * 60.0)`, puis mise a jour position. Inclut un systeme de sleep : bodies quasi-immobiles pendant 30 frames sont endormis et ignores par la simulation.

**`PattounX_zone`** : wrapper autour d'un `ItemSnapable` et son `ZoneParameter`. Fournit les tests de collision (statique et sweep) et l'acces aux parametres (friction, vitesse, acceleration, exclusion).

### Detection de collision continue (CCD)

**21 decembre** — premiere implementation CCD par echantillonnage discret (4-50 pas adaptatifs).

**Avril 2026** — remplacement par un **sweep analytique** (`sweepCircleSegment`) :

```cpp
// Pour chaque segment du polygone :
// 1. Cercle vs sommets : resolution quadratique
//    |P0 + t*V - vertex|^2 = r^2
// 2. Cercle vs corps du segment : projection sur la normale
//    d0 + t*dv = ±radius, puis clamp sur le segment
// Le plus petit t dans [0,1] donne le point d'impact exact.
```

Le moteur utilise un **CCD rewind** : apres integration, le body est rembobine au point d'impact (`prevPos + t * movement`), puis le bounce/slide est applique sur la velocite. Cela empeche le tunneling meme a haute vitesse.

**27 decembre** : resolution iterative avec friction Coulomb (moyenne geometrique body/zone) et restitution (`resolveCollisions(contacts, dt)`, `correctPositions(contacts)`). Signaux de collision dedupliques par paire body/zone.

### Construction du moteur — jour par jour

| Date | Commit | Ce qui change |
|---|---|---|
| 13 dec | `17e1f3d` | Premiere version zones d'exclusion |
| 14 dec | `a0bc12f` | Refactoring EntityController — mouvement et collision 2D |
| 14 dec | `89987f8` | Refactoring 2D movement et collision logic |
| 16 dec | `12a38d5` | Fix angle de rebond |
| 20 dec | `20a30d5` | Migration moteur en C++ pur (hors QML) |
| 21 dec | `a405cdf` | **CCD** — continuous collision detection pour cercles |
| 21 dec | `9268a48` | Refactoring PhysicsZone2D -> ZoneParameter |
| 22 dec | `af06429` | Zones de force et modificateurs |
| 27 dec | `238a0a2` | Renommage global -> pattounx_*, friction/restitution |
| 28 dec | `d285c1a` | EntityController -> EntityEngine |

### Templates (Valere)

**21-23 decembre** : nouveau repertoire `cpp/game/template/` :

- **`TemplateFileManager`** (singleton QML) : gere `DEFAULT_TEMPLATE_PATH` et `USER_TEMPLATE_PATH`. Format JSON `{ "templateInfo": {...}, "elements": [...] }`. `convertElementsToTemplateFormat(elements, originX, originY)` convertit positions absolues -> relatives.
- **`ItemSnapableFactory`** : `Q_INVOKABLE ItemSnapable* createItemSnapableFromJson(const QJsonObject&)`

Cote QML, `MouseLogic_Template.qml` gere la selection de groupe avec rectangle englobant. Snap de groupe sur grille : `snappedX = Math.round(newX / grid.gridSize) * grid.gridSize`.

### Refactoring QML en modules

Migration vers des `qmldir` formels. Exemple :
```
module CaseConfigPanel
CaseConfigurationPanel 1.0 CaseConfigurationPanel.qml
CCP_CardBoardBoxSpecificConfig 1.0 CCP_CardBoardBoxSpecificConfig.qml
...
```

Modules crees : `CaseConfigPanel` (23 composants), `VisualEffectPanel` (13), `CaseSelectionPanel`, `EditorBottomPanel`, `MapSelectionPanel`, `SidePanel`, `MapInfoPanel`, `zonepanel`.

**Etat du projet** : moteur physique custom avec CCD, templates, modules QML.

---

## Chapitre 8 : Le Chat E2EE (Janvier 2026)

### Le jour de l'An le plus productif

Le 1er janvier 2026, Antoine code le serveur de chat en entier.

**Serveur Node.js** (`chatServer/server.js`) : relais WebSocket aveugle base sur `ws` + `better-sqlite3`. Schema SQLite :

```sql
sessions(session_id PK, key_package TEXT, key_nonce TEXT, created_at)
messages(id, session_id FK, sender_id, payload, nonce, key_version, server_timestamp)
```

**Protocole WebSocket** (commandes JSON `type`/`payload`) :
- `JOIN_SESSION` / `PUBLISH_KEY` / `SEND_MSG` / `GET_HISTORY`
- Reponses : `INIT_SESSION`, `KEY_UPDATE`, `NEW_MESSAGE`, `HISTORY_RESULT`
- Rooms en memoire : `Map<sessionId, Set<WebSocket>>`

En une journee : serveur + support images + compression + historique + script de deploiement.

### Le systeme E2EE

**Primitives crypto** (`chat_crypto.cpp`) :
- Chiffrement symetrique **AES-256-GCM** (via Qt/OpenSSL)
- `generateRandomKey()` : cle 256 bits
- `generateNonce()` : nonce aleatoire
- `deriveLockKey(sessionId, password)` : cle de verrou locale (jamais transmise)
- `derivePasswordProof(sessionId, password)` : preuve de mot de passe pour le serveur
- `decrypt()` : verification MAC a temps constant (ajoute 7 fevrier)

**Protocole blind relay** :
1. Le client genere une `sessionKey`
2. Il la chiffre avec `lockKey = deriveLockKey(sessionId, password)` -> `encrypted_pkg`
3. Il publie `{blob: encrypted_pkg, nonce}` via `PUBLISH_KEY`
4. Le serveur stocke le blob et le rediffuse a tous les membres via `KEY_UPDATE`
5. Chaque client dechiffre localement avec son propre `lockKey`
6. **Le serveur ne voit jamais ni le mot de passe ni la cle de session en clair**

**Rotation de cles** (7 fevrier) : quand un nouveau participant rejoint, le serveur emet `NEW_PARTICIPANT` -> le client repond avec `publishNewKey()` -> versionnement `key_version` sur chaque message.

### ChatClient C++

**2 janvier** : `ChatWorker` (nouveau fichier) herite de `QObject`, possede le `QWebSocket`, est deplace dans un `QThread` dedie. `ChatClient` communique via `QMetaObject::invokeMethod(..., Qt::QueuedConnection)`. Emissions de signaux QML dans le thread GUI.

Flux de session :
1. `connectToServer(url, playerId, password)` -> invoque `ChatWorker::connectToServer` dans le thread reseau
2. `onConnected()` -> envoie `JOIN_SESSION` avec `player_id`, `session_id`, `password_hash`
3. `handleInitSession()` -> traite les cles chiffrees, dechiffre avec `m_lockKey`
4. `handleNewMessage()` -> dechiffre, sauvegarde en DB locale, emet `messagesChanged()`

### AccountManager

**25 janvier** : singleton persistant dans `QSettings` :
- `uniqueId` : UUID v4 genere une fois (passe a 8 chars regenerables le 7 fevrier)
- `nickname` : pseudo local
- `privateKey` : cle 256 bits stockee en base64
- `keyCreatedAt` : date de generation
- `regenerateKeys()` : rotation manuelle
- `m_stunServer` / `m_stunPort` : serveur STUN configurable, synchronises vers `StunManager`

### Migration CMake (Valere)

**31 janvier** : `Meownopoly.pro` renomme `.pro.disabled`, nouveau `CMakeLists.txt` (186 lignes) :

```cmake
cmake_minimum_required(VERSION 3.21)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
find_package(Qt6 REQUIRED COMPONENTS Core Quick Qml Widgets
    QuickControls2 Network WebSockets Sql Quick3D Concurrent)
file(GLOB_RECURSE SOURCES "cpp/*.cpp")
```

Presets debug/release, chemins OpenSSL conditionnels par developpeur (Antoine/Valere, Android vs Desktop).

**Etat du projet** : chat E2EE complet, comptes locaux, CMake.

---

## Chapitre 9 : La Revolution Reseau — Catway (Fevrier 2026)

> Le mois le plus ambitieux techniquement. Antoine construit une stack P2P complete.

### STUN et decouverte NAT

**9-14 fevrier** : `StunManager` possede le `QUdpSocket`, envoie des requetes STUN RFC 5389, parse `MAPPED-ADDRESS` (0x0001) et `XOR-MAPPED-ADDRESS` (0x0020), emet `externalAddressReceived(ip, port)`.

`UdpSocketInfo` : conteneur QML exposant `{socket, publicAddress, publicPort}` — permet de gerer plusieurs sockets UDP simultanement (un par joueur P2P).

### Architecture Catway

`Catway` (singleton QML) evolue :
- `setupNewPort()` : demarre un socket UDP, envoie STUN, puis `takeSocket()` detache le socket du StunManager, cree un `UdpSocketInfo`
- `PlayerNetwork` : type QML (`playerId`, `nickname`, `ip`, `port`, `socketInfo*`)
- `getOrCreatePlayer(senderId)` : creation lazy depuis les commandes de chat

### UDP Hole Punching (21 fevrier)

Protocole en 3 etapes visible dans les diffs :

```
1. INITIATEUR appelle initiateHolePunch(player):
   -> Envoie via WebSocket: UDP_HOLE_PUNCH_REQUEST {ip, port}
   -> Envoie UDP brut: "HP:STRIKE" vers IP:port public du pair

2. CIBLE recoit UDP_HOLE_PUNCH_REQUEST via onChatCommandReceived:
   -> Memorise IP/port
   -> Envoie UDP: "HP:REPLY"

3. INITIATEUR recoit "HP:REPLY":
   -> Envoie "HP:FINAL"
   -> Connexion etablie
```

Discrimination par magic byte dans `onPlayerUdpReadyRead()` :
```cpp
if (datagram[0] == '\x01')  // paquet reliable.io
    reliable_endpoint_receive_packet(...)
else  // paquet brut
    // parse HP:REPLY / HP:FINAL / HP:STRIKE ou message legacy
```

### Integration reliable.io (22 fevrier)

La bibliotheque `reliable.c` (2 576 lignes) est embarquee dans `cpp/reliable/`.

Configuration dans `PlayerNetwork` :
```cpp
void initReliable(void *context, transmitFn, processFn);
// max_packet_size=32KB, fragment_above=1200, max_fragments=32, fragment_size=1024
```

Callbacks statiques C dans `catway.cpp` :
- `catway_transmit_packet()` : prefixe avec `\x01`, envoie via `writeDatagram()`
- `catway_process_packet()` : emet `reliableMessageReceived` via `QMetaObject::invokeMethod(..., Qt::QueuedConnection)`

Timer a ~60 Hz dans `CatwayWorker::onReliableUpdate()` : appelle `reliable_endpoint_update()` et `reliable_endpoint_clear_acks()` pour chaque joueur.

### Thread reseau (27 fevrier)

`CatwayWorker` dans son propre `QThread`. `StunManager` et timers `reliable` deplaces dans le worker. Les `QUdpSocket` migres via `moveToThread()`. Connexions signal/slot avec `Qt::QueuedConnection`. Anti-spoofing UDP ajoute le meme jour.

### En parallele — Valere : Lobby & Sessions

Le serveur chat evolue considerablement en fevrier :
- `CREATE_SESSION` avec limite `MAX_SESSIONS` et broadcast
- Colonne `password_hash` dans `sessions`
- Commandes : `KICK`, `DELETE_SESSION`, `LEAVE_SESSION`, `CLEAR_HISTORY`, `GET_PARTICIPANTS`
- `LIST_SESSIONS` agrege DB + rooms en memoire
- Messages prives ephemeres (non persistes)
- `SEND_COMMAND` : canal de commandes P2P chiffrees

Cote QML : `MultiplayerLobby.qml`, `SessionCreation.qml`, `ChatSessionManager`, auto-refresh du lobby.

### La commande /create

Antoine ajoute la possibilite de creer des elements dans l'editeur via des commandes chat (`/create`). `Support /create command and snapable creation` : premier pont entre communication et editeur.

**Etat du projet** : P2P fonctionnel, lobby multijoueur, chat E2EE complet.

---

## Chapitre 10 : Consolidation (Mars - Avril 2026)

### Refactoring Catway (31 mars - 4 avril)

Apres 2 semaines de pause, Antoine revient avec *"we are back !"* et refactore Catway en profondeur en une nuit.

**Commit `153ce75` (1er mars)** : extraction de ~185 lignes de `catway.cpp` vers `catway_worker.cpp` :
- `CatwayWorker::initReliable()` — initialisation reliable.io
- `startReliableTimer()` — timer 16ms (~60 Hz)
- `onSocketReadyRead()` — lecture UDP sur le thread reseau
- `sendReliablePacket()` / `sendDatagram()` — envois thread-safe

**Commit `2711fb2` (31 mars)** : division de `catway.cpp` en trois fichiers (`catway_player.cpp`, `catway_stun.cpp`, `catway.cpp`). Introduction des **`PlayerSnapshot`** : objets immuables copies sur le thread reseau pour eviter les races GUI/reseau. Suppression de `Qt::BlockingQueuedConnection` (sources de deadlocks).

**Commit `adb967a` (4 avril, avec Claude)** : extraction des helpers de relay. La boucle de relay hote etait **dupliquee 3 fois** dans `game_session.cpp` — extraite en :

```cpp
void GameSession::relayReliableToOthers(const QString &senderId, const QByteArray &packet);
void GameSession::relayRawToOthers(const QString &senderId, const QString &message);
```

Et un helper pour les casts repetes :
```cpp
static inline uint8_t *toReliableBytes(const QByteArray &ba) {
    return reinterpret_cast<uint8_t *>(const_cast<char *>(ba.constData()));
}
```

### Game Networking (7 mars)

**Commit `7aca3d8`** (+704 lignes) : protocole de jeu reseau complet.

**`game_message_type.h`** : enum binaire avec deux canaux :
- **Canal fiable** (reliable UDP) : `GameStart=0x01`, `TurnStart=0x03`, `DiceRoll=0x04`, `PlayerMove=0x05`, `BuyProperty=0x06`, `PayRent=0x07`, `MapSync=0x0D`...
- **Canal brut** (tolerant la perte, pour minijeux) : `MinigameInput=0x10` (60 Hz), `MinigameSnapshot=0x11` (reliable ~1 Hz)

**`game_protocol.cpp`** : serialisation binaire — fiable : `[1 octet type][JSON UTF-8]`, minijeu : `"MG:<x>;<y>;<vx>;<vy>"`.

**`game_session.cpp`** : singleton `GameSession`, modes hote/client. L'hote est **autoritaire** : a reception d'un evenement, il le relaie a tous les autres.

**`minigame_sync.cpp`** : deux timers — 60 Hz pour l'envoi des inputs locaux, ~30 Hz pour l'emission vers QML (evite de saturer le thread GUI). Les inputs recus sont bufferises dans un `QHash` avant d'etre flushes.

### Undo/Redo v2 — systeme delta (Valere, 15 mars)

**Commit `6b032e6`** : remplacement complet de `UndoRedoManager` (222 lignes supprimees) par un systeme delta :

```cpp
namespace EditDeltaType {
    enum Type { TileModified=0, TileAdded=1, TileDeleted=2, MetadataChanged=3 };
}

struct EditDelta {
    EditDeltaType::Type type;
    QUuid tileId;
    QUuid groupId;        // null = atomique, meme ID = transaction
    QJsonObject before;   // {} si TileAdded
    QJsonObject after;    // {} si TileDeleted
};
```

Dans `Map` : `QStack<EditDelta>` undo/redo. Dans `ItemSnapable` : shadow copy (`m_lastKnownJson`, `commitCurrentState()`) pour calculer le `before` d'un delta.

API `Game` : `beginTransaction()` -> retourne un `QUuid`, `updateEditState(type, tile, groupId)`, `commitTransaction()`. Les transactions groupent plusieurs deltas pour un undo/redo atomique.

### MapFileManager (15 mars - 2 avril)

Registre central de la carte courante. `Game::loadMap()` appelle `MapFileManager::instance()->setCurrentMap(map)`. **Save-on-edit** : `saveOnEdit()` lit `QSettings("Editor/SaveConfig", "saveEvent") == "3"` et appelle `saveCurrentMap()` apres chaque delta si le mode est active.

### Outillage (avril)

**CLAUDE.md** (5 avril) : 104 lignes documentant l'architecture pour l'assistant IA.

**GitHub Actions** (4 avril) : `.github/workflows/claude.yml` declenche sur `@claude` dans les commentaires de PR.

**Deploy Windows** (7 avril) : `CMakeLists.txt` genere dynamiquement `deploy_$<CONFIG>.bat` via `file(GENERATE ...)` qui lance `windeployqt` en Release. `script/sync_from_remote.sh` (64 lignes) : rsync SSH avec options par variables d'environnement.

**Etat final du projet** : jeu de plateau reseau avec editeur complet, chat E2EE, P2P par UDP hole punching, moteur physique custom, protocole de jeu binaire.

---

## Chronologie Technique

```
Jan 25  [GENESE]        Qt/QML + qmake, Case/Player/Game, CSV loader,
   |                    composants UI stylises (recuperes d'un projet precedent)
   |
Mar 25  [PROTO]         Integration Ollama LLM (traduction auto), 38 cases,
   |                    BoardGrid/BoardTile/AnimatedPlayerToken, ControlPanel
   |
   |    ~~~~ 4 mois de pause ~~~~
   |
Jul 25  [V2 + DUO]     "The Purge" (-735 lignes), Valere rejoint
   |                    CaseCatPerks (mixin achetable), CaseFactory partiel
   |                    JSON remplace CSV, liste chainee multi-branches
   |                    14 composants QML par type de case
   |                    Game design formalise (copro, encheres, 4 phases)
   |
Aou 25  [EDITEUR]       ItemSnapable + DisplayParameter (C++)
   |                    GridManager, SnapableElement (QML)
   |                    EditorLogic + EditorDynamicComponent (separation)
   |                    ConnectionOverlay (2 methodes testees)
   |                    AssetManager + AssetModel (QAbstractListModel)
   |                    LauncherManager + asset_server (Node.js, .meow)
   |                    Map/MapLoader, serialisation JSON 2 passes
   |                    VisualEffectsPanel (668 lignes, 12 effets)
   |
Sep 25  [UX]            MouseLogic_Base/Selection/Pose (Loader dynamique)
   |                    Multi-selection AABB (SelectionRect.qml)
   |                    Effets visuels verrouillables + application batch
   |                    CSP/MSP/MenuSelector (Valere, refactoring massif)
   |
Oct 25  [FEATURES]      AnimatedSprite -> AnimatedImage (changement d'approche)
   |                    CaseFactory::createCase (switch complet)
   |                    MouseLogic_Selection_link (liens par clic)
   |                    Case config panels (chemin selectionPanel.casePanel...)
   |                    image_tools (BiRefNet, double-pass, WebP pipeline)
   |                    Autosave debut (MapType enum, Timer debounce 100ms)
   |
Nov 25  [BOARD]         GameBoard.qml + GameDynamicComponent (separation jeu/editeur)
   |                    UndoRedoManager v1 (QVector<QJsonObject>, clearRestorationFlag)
   |                    EditorSidePanel (redimensionnable, animation 300ms)
   |                    Quick3D : View3D, OrthographicCamera -55deg, modele .glb
   |
Dec 25  [PHYSIQUE]      ExclusionParameter -> PolygonParameter -> ZoneParameter
   |                    PhysicsBody2D -> PattounX_body (Euler semi-implicite)
   |                    PattounX_zone (Exclusion/Speed/Friction)
   |                    CCD : checkCirclePolygonSweep (4-50 steps adaptatif)
   |                    resolveCollisions + correctPositions (friction/restitution)
   |    [Avr 26]         CCD analytique (sweepCircleSegment, resolution quadratique)
   |                    CCD rewind anti-tunneling, sleep system, broadphase AABB
   |                    Friction Coulomb (moyenne geometrique), signaux dedupliques
   |                    TemplateFileManager (positions absolues -> relatives)
   |                    Modules qmldir (23+ composants enregistres)
   |
Jan 26  [CHAT]          chatServer/ (ws + better-sqlite3, blind relay)
   |                    Protocole : JOIN_SESSION/PUBLISH_KEY/SEND_MSG/GET_HISTORY
   |                    AES-256-GCM, deriveLockKey, derivePasswordProof
   |                    ChatWorker dans QThread dedie
   |                    AccountManager (QSettings, cle 256 bits, UUID 8 chars)
   |                    CMakeLists.txt (Valere, C++20, Qt6, GLOB_RECURSE)
   |
Fev 26  [RESEAU]        StunManager (RFC 5389, MAPPED-ADDRESS, XOR-MAPPED-ADDRESS)
   |                    Catway singleton + UdpSocketInfo + PlayerNetwork
   |                    Hole punch : HP:STRIKE -> HP:REPLY -> HP:FINAL
   |                    reliable.io embarque (32KB max, fragments 1024)
   |                    Magic byte 0x01 = reliable, sinon = brut
   |                    CatwayWorker thread (moveToThread, PlayerSnapshot)
   |                    Lobby/Sessions (CREATE/JOIN/KICK/DELETE/LIST)
   |
Mar 26  [STABILISATION] catway.cpp -> catway_player/stun/worker (3 fichiers)
   |                    GameSession (hote autoritaire, relay)
   |                    GameMessageType (0x01-0x0D fiable, 0x10+ brut)
   |                    MinigameSync (60Hz input, 30Hz render, QHash buffer)
   |                    EditDelta (before/after JSON, transactions groupees)
   |                    MapFileManager (save-on-edit conditionnel)
   |
Avr 26  [OUTILLAGE]     CLAUDE.md, GitHub Actions, windeployqt, rsync
```

---

## Architecture Finale — Vue Technique

### Modele de threading

| Couche | Technologie | Thread |
|---|---|---|
| UI QML | Qt Quick | GUI |
| `Catway` (singleton) | Qt signals/slots | GUI |
| `CatwayWorker` | QThread dedie | Reseau |
| `StunManager` / `QUdpSocket` | Qt Network | Reseau |
| `reliable.io` | C pur + callbacks | Reseau |
| `ChatClient` / `ChatWorker` | QWebSocket | Reseau |
| `AccountManager` | QSettings | GUI |
| Serveur chat | Node.js + ws + SQLite | Serveur distant |

### Protocole reseau

```
Couche 4 (Jeu)     : GameMessageType [1 byte type][JSON UTF-8]
Couche 3 (Fiabilite): reliable.io [fragmentation, ACK, reassemblage]
Couche 2 (Mux)     : magic byte 0x01 = reliable, sinon = brut
Couche 1 (Transport): UDP socket (hole-punched)
Couche 0 (NAT)     : STUN discovery + HP:STRIKE/REPLY/FINAL
```

### Hierarchie des cases

```
Case (QObject)
 |-- CaseCatPerks (mixin achetable : price, owner, buyCase/sellCase)
 |    |-- CaseRestArea (loyers par niveau RQ_NONE..RQ_HOTEL)
 |    |-- CaseCatDoor (gares)
 |    |-- CaseCatDevice (compagnies)
 |-- CaseKibbleDispenser (depart + taxe)
 |-- CaseJail
 |-- CaseToJail
 |-- CaseFreeNap (parking gratuit)
 |-- CaseCardBoardBox (cartes chance)
 |-- CaseCatNip (herbe a chat)

CaseFactory::createCase(CaseType) -> switch complet
```

### Systeme de l'editeur

```
Editor.qml
 |-- EditorLogic.qml (QtObject : snapableTilesList, selectedElement, mouseMode)
 |    |-- MouseLogic_Base.qml (fonctions polymorphiques)
 |    |    |-- MouseLogic_Selection.qml (drag, multi-select, AABB)
 |    |    |    |-- MouseLogic_Selection_link.qml (creation liens)
 |    |    |    |-- MouseLogic_Template.qml (groupes, bounding box)
 |    |    |-- MouseLogic_Pose.qml (placement d'assets)
 |    |-- TileLogic.qml (connexions, taille, rotation)
 |-- EditorDynamicComponent.qml (Component factories)
 |-- GridManager.qml (grille, snap, zoom)
 |-- SelectionPanel (ASP + CSP + VEP + CCP)
 |-- BottomSidePanel (qml/editor/panel/bottomPanel/bottomSidePanel/)
```

---

## Qui fait quoi ? (Verifie par les diffs)

### Antoine (antoinnneee) — ~642 commits

| Domaine | Classes/fichiers cles |
|---|---|
| Reseau P2P | `Catway`, `CatwayWorker`, `StunManager`, `PlayerNetwork` |
| Moteur physique | `PattounX_engine` (pattounx_engine_v2), `PhysicsWorld`, `PhysicsWorker`, `PhysicsSession`, `Collision2D` |
| Chat backend | `chatServer/server.js`, `ChatClient`, `ChatWorker`, `ChatCrypto` |
| Editeur core | `GridManager`, `EditorLogic`, `MouseLogic_*`, `ConnectionOverlay` |
| Assets | `AssetManager`, `AssetModel`, `LauncherManager`, `asset_server/` |
| Jeu reseau | `GameSession`, `GameProtocol`, `MinigameSync` |
| Infrastructure | `pattounecorp.ovh`, STUN server, deploy scripts |

### Valere (Valere21) — ~450 commits

| Domaine | Classes/fichiers cles |
|---|---|
| UI editeur | `ASP_*`, `CSP_*`, `MSP_*`, `VEP_*`, `BottomSidePanel` |
| Cases | `CaseFactory`, `CaseCatPerks`, `CaseCatDevice`, hierarchie complete |
| Board | `GameBoard.qml`, `GameDynamicComponent`, deplacement joueur |
| Persistance | `Map`, `MapLoader`, `MapFileManager`, `UndoRedoManager` -> `EditDelta` |
| Templates | `TemplateFileManager`, `MouseLogic_Template` |
| Build | Migration qmake -> CMake, presets, chemins OpenSSL |
| Lobby | `MultiplayerLobby.qml`, `SessionCreation.qml`, `ChatSessionManager` |

### Zones de chevauchement

- **ItemSnapable** : Valere cree la structure C++, Antoine ajoute `DisplayParameter` et la serialisation JSON
- **SnapableElement** : Antoine pose le QML, Valere ajoute les animations et la selection
- **Editeur** : Antoine fait le core logic + mouse, Valere fait les panneaux + UI
- **Save/Load** : Antoine fait `Map`/`MapLoader`, Valere ajoute autosave et undo/redo

---

## Patterns Observes dans le Code

### Style de commit
- **Antoine** : messages descriptifs ou tres courts (*"s"*, *"u"*, *"wip"*), travaille en rafales intenses le soir
- **Valere** : messages souvent en anglais, prefixe WIP explicite, crie en majuscules (*"RESOLVED TRANSPARICY CHECK"*, *"WORK IN PROGRESS"*)
- Les merges sont frequents (souvent plusieurs par jour)

### Sessions de coding les plus intenses
- **14 juillet 2025** : 25+ commits, debut V2, les deux devs de 13h a 22h
- **24 aout 2025** : 20+ commits, editeur marathon de 11h a 23h
- **15 septembre 2025** : Valere code de 2h a 7h du matin sur les panneaux
- **31 janvier 2026** : Valere code toute la nuit (1h-8h) pour la migration CMake et les templates

### Decisions architecturales majeures

1. **La Purge (Jul 25)** : repartir de zero plutot que d'iterer sur le prototype. Suppression de 735 lignes de code jamais integre (Ollama, tests, crash handler). Decision payante.

2. **Liste chainee multi-branches (Jul 25)** : `Case.next[]` / `Case.prev[]` au lieu d'un tableau lineaire. Permet des plateaux avec embranchements et raccourcis. Plus complexe mais plus expressif.

3. **SnapableElement comme abstraction unifiee (Aou 25)** : `ItemSnapable` + `DisplayParameter` unifient tiles, decorations, et cases. Serialisation JSON a deux passes (construction puis resolution des liens par UUID).

4. **Mouse Logic modulaire (Sep 25)** : composants QML interchangeables charges par `Loader`. Heritage `Base -> Selection -> Link/Template`. Ajout de modes sans toucher au code existant.

5. **AnimatedSprite -> AnimatedImage (Oct 25)** : apres avoir lutte avec `AnimatedSprite` (frameWidth, frameHeight, transparence), Valere bascule sur `AnimatedImage` natif qui supporte `.webp` anime sans configuration.

6. **Moteur physique custom (Dec 25, maj Avr 26)** : PattounX from scratch. CCD analytique (sweep quadratique cercle-segment) avec rewind anti-tunneling. Euler semi-implicite, damping exponentiel framerate-independant, friction Coulomb (moyenne geometrique), sleep system, broadphase AABB. Plus de controle que Box2D, mais plus de maintenance.

7. **E2EE blind relay (Jan 26)** : AES-256-GCM, derivation de cle locale, rotation de cle par version. Le serveur ne voit jamais les messages en clair. Choix de securite fort.

8. **UDP hole punching 3 etapes (Fev 26)** : STUN RFC 5389, HP:STRIKE/REPLY/FINAL, magic byte 0x01 pour muxer reliable/brut. Zero cout serveur pour le gameplay.

9. **Undo/Redo delta vs snapshot (Mar 26)** : v1 stockait des snapshots JSON complets. v2 stocke des deltas `{before, after, groupId}` avec transactions groupees. Plus leger, plus precis.

10. **Migration qmake -> CMake (Jan 26)** : necessaire pour Android, Linux, multi-developpeur. `GLOB_RECURSE` + presets + chemins conditionnels par dev.

---

## Anecdotes du Git Log

- *"zo"* (14 juillet) : premier commit de Valere. Sobre.
- *"euhhhh"* (13 juillet) : +2 206 lignes QML apres 4 mois de silence — la tete d'Antoine en redecouvrant le code.
- *"The purge !!!"* (14 juillet) : -735 lignes. L'IA Ollama, les tests, le crash handler — tout passe a la trappe.
- *"mr propre"* : revient 3 fois dans l'historique.
- *"qwerty"*, *"qwer"*, *"wert890"*, *"asdftyuio"* : push rapides, probablement `git commit -m` + touches au hasard.
- *"C'est de la merde"* (12 septembre) : avant un refactoring heroique des panneaux.
- *"on clean derriere valere"* (17 aout) : le quotidien du duo.
- *"temperature: 1.5"* dans l'integration Ollama : experimentation audacieuse pour une traduction.
- *"Bug on kibble dispenser"* (19 juillet, 1h du matin) : on debug les distributeurs de croquettes en pleine nuit.
- *"No idea what is this push"* (2 avril 2026) : quand le crash a efface la memoire.
- Le debug ANSI casse depuis le premier commit (`"033[31m"` au lieu de `"\033[31m"`) : corrige discretement dans The Purge.

---

## Bugs Notables (Trouves dans les Diffs)

| Date | Bug | Resolution |
|---|---|---|
| Oct 25 | `AnimatedSprite` : `isTransparent()` referenceait `loaderImage.paintedHeight` au lieu de `loaderImage.item.paintedHeight` | Fix + guard `typeof`, puis abandon de `AnimatedSprite` |
| Nov 25 | `UndoRedoManager` : flag `isRestoringState` remis a `false` trop tot -> sauvegardes parasites pendant rechargement QML | QML appelle `clearRestorationFlag()` manuellement |
| Mar 26 | `GameBoard.qml` : timers anti-race condition (3s) pour debloquer des flags d'animation coinces | Timers de securite |
| Mar 26 | Relay hote duplique 3 fois dans `game_session.cpp` | Extraction en `relayReliableToOthers` / `relayRawToOthers` |
| Mar 26 | `Catway` : `Qt::BlockingQueuedConnection` causant des deadlocks potentiels | Remplaces par `PlayerSnapshot` immutables + `QueuedConnection` |
| Mar 26 | `Catway::chatClient` : dangling pointer apres suppression | Mise a `nullptr` avant `delete` |
| Mar 26 | `MinigameSync` : signaux trop frequents (60Hz) saturant le thread GUI | Buffer `QHash` + flush a 30Hz |

---

*Document genere le 7 avril 2026 a partir de l'analyse des diffs reels de 1 092 commits.*
