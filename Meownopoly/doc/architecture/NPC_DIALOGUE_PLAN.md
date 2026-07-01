# Plan — PNJ avec lignes de dialogue dans l'éditeur

> Statut : **implémenté (2026-07-01, phases 1-6)**. Ce document décrit l'ajout
> d'un type d'élément « PNJ » (personnage non-joueur) porteur d'une séquence de
> dialogue, posable et configurable dans l'éditeur, affiché en jeu dans la
> présentation 3D. Voir « État d'implémentation » en fin de document pour les
> écarts par rapport au plan initial.

## Contexte

L'éditeur permet aujourd'hui de poser des **cases**, des **décorations** (assets 2D)
et des **zones physiques**. Il manque un moyen de peupler le plateau de
**personnages non-joueurs (PNJ)** porteurs de texte. Objectif : pouvoir, depuis
l'éditeur, poser un PNJ, lui donner une identité (nom + visuel), une **séquence de
lignes de dialogue**, et un **mode de déclenchement** ; et voir ce dialogue
s'afficher en jeu.

Décisions produit validées :
- **Visuel** : le PNJ peut porter un **modèle 3D** (pipeline `SkinnedModel`/`.glb`
  existant) *ou*, à défaut, un **sprite 2D** (pipeline `DecorationParameter`).
- **Déclenchement** : configurable — `Proximité` / `Clic` / `Toujours visible`. La
  **zone de proximité doit être éditable/déplaçable avec l'outil de zones existant**
  → on **lie** le PNJ à une `PhysicZoneTile` standard via le système de liens
  `next/prev` déjà présent (réutilise l'éditeur de zones à 100 %, sans le modifier).
- **Texte** : une **séquence ordonnée** de lignes, une visible à la fois, avancée par
  le joueur (clic/touche).

Aucun système de dialogue/bulle in-game n'existe aujourd'hui — c'est la seule brique
entièrement neuve. Tout le reste réutilise des patterns en place.

---

## Architecture retenue (réutilisation maximale)

| Besoin | Réutilise |
|---|---|
| Type d'élément placeable + sérialisation | `ItemSnapable` + nouveau `TileType::NPCTile` + nouvelle classe `NPCParameter` |
| Visuel sprite 2D | `DecorationParameter` déjà porté par `ItemSnapable` |
| Visuel 3D | `SkinnedModel.qml` + `PhysicsActor.qml` (comme les joueurs) |
| Zone de trigger déplaçable | `PhysicZoneTile` standard **liée** au PNJ (`next/prev` + op `LinkItems`) |
| Détection d'entrée dans la zone | signaux `pattounxWorld.actorEnteredZone/ExitedZone` (émis par les zones non-exclusion) |
| Logique d'écoute zone→élément | pattern de `ScreenEffectController.qml` (copie quasi à l'identique) |
| Collab / undo | ops existantes `CreateItem` / `DeleteItem` / `LinkItems` (+ 1 nouvelle op `SetNpcParameter`) |
| Placement programmatique / tests | hooks `editorAutomationHooks` dans `Editor.qml` |

**Clé du design** : le PNJ (visuel + dialogue) et sa zone de proximité sont **deux
tiles distinctes reliées par un lien**. Déplacer/reshaper la zone = éditer une zone
normale. En jeu, l'entrée dans la zone (`actorEnteredZone(zoneId)`) est résolue vers
la tile PNJ liée, qui porte la séquence de dialogue.

---

## Modèle de données — `NPCParameter` (nouveau, C++)

Nouvelle classe `cpp/game/item_snapable/npcparameter.{h,cpp}`, calquée sur
`ZoneParameter` (mêmes conventions : `Q_PROPERTY`, `toJSON()` par concaténation,
ctor `(const QJsonObject&)`, `applyJson()`, `operator==`).

Champs :
- `QString npcName` — nom affiché.
- `int visualKind` — `0 = Model3D`, `1 = Sprite2D` (enum `Q_ENUM`). Le sprite
  réutilise le `DecorationParameter` déjà présent sur l'`ItemSnapable` (triplet
  category/type/id) ; le modèle 3D utilise `modelName`.
- `QString modelName` — nom du modèle `.glb` (`<AppData>/models/<modelName>/`), vide si sprite.
- `QStringList dialogueLines` — liste ordonnée (séquence). Exposée en lecture ;
  l'édition passe par des `Q_INVOKABLE` (`addLine/insertLine/setLineAt/removeLineAt/
  moveLine/clearLines/lineCount`) pour éviter le gotcha « mutation en place non
  observée » (même raison que `ZoneParameter::addPoint`).
- `int triggerMode` — enum `Q_ENUM` `Proximity=0 / Click=1 / Always=2`.
- `bool advanceOnClick` (option) — sinon touche.
- `int npcVersion = 1` — versionnage de schéma (analogue à `playerConfigVersion`).

**Piège sérialisation** : les autres `toJSON()` du projet concatènent des chaînes à
la main. Pour `dialogueLines` (texte libre pouvant contenir guillemets / retours à la
ligne), **construire le JSON via `QJsonObject` + `QJsonArray` +
`QJsonDocument::toJson(Compact)`** au lieu de la concat manuelle, sinon l'échappement
casse. `applyNpcSettings`/remote-apply remplace le tableau complet (`clearLines()` +
`addLine`) plutôt qu'une mutation en place.

Enregistrement QML : ajouter `qmlRegisterType<NPCParameter>(...)` dans
`ItemSnapable::registerQml()` (`ItemSnapable.cpp:26`).

**Sens du lien NPC↔zone** : le NPC est *source*, la zone trigger est son `next`. Le
runtime résout `zoneId → tile zone → getPrevList() → NPC`.

---

## Fichiers à modifier / créer

### 1. Backend C++ (`cpp/game/item_snapable/`)
- **`ItemSnapable.h`** — ajouter `NPCTile` à l'enum `TileType` (l.40-44) **en
  dernière position** ; ajouter `Q_PROPERTY npcParameter` + membre `m_npcParameter`.
- **`ItemSnapable.cpp`** :
  - Ctor JSON (l.54-114) : **étendre la borne de validation**
    `rawTileType > PhysicZoneTile` → `> NPCTile` (sinon les PNJ chargés retombent en
    `DecorationTile`). Parser `"npcParameter"`.
  - `toJSON()` (l.175-203) : sérialiser `npcParameter` (au moins quand `NPCTile`).
  - `applyJson()` (l.299-328) : appliquer `npcParameter`.
  - `operator==` (l.90-124) : ajouter le cas `NPCTile`.
  - `registerQml()` : enregistrer `NPCParameter`.
- **`npcparameter.{h,cpp}`** — nouveau (cf. section modèle de données).
- **`itemsnapablefactory.{h,cpp}`** — `createNPC()` (crée un `ItemSnapable` `NPCTile`
  avec `NPCParameter` par défaut, réutilise le chemin `createItemSnapable()`).
- **CMake** : `GLOB_RECURSE` ramasse les `.cpp` mais est figé au configure →
  **reconfigurer** avant build.

### 2. Protocole collab (`cpp/editor/`)
- **Ops** : la pose (`CreateItem`), la suppression (`DeleteItem`) et le lien
  PNJ↔zone (`LinkItems`) réutilisent l'existant. Ajouter **une** op
  `SetNpcParameter` (édition du nom / des lignes / du mode) sur le modèle de
  `SetZoneParameter` dans `EditorOpType` + `EditorOpBus` (helper
  `makeSetNpcParameterOp`) + remote apply dans `Editor.qml`.
- **`editor_protocol.cpp`** : `SetNpcParameter` transite via `EditorMessageType::Op`
  (0x23) déjà couvert par `isEditorPacket` → pas de nouveau `EditorMessageType`. Si
  un jour un type dédié est ajouté, il doit être la valeur la plus haute (cf. CLAUDE.md).

### 3. UI éditeur (`qml/editor/`)
- **`moduleManager/ModuleManager.qml`** (l.49-58) : ajouter le module `"npc"`.
- **`moduleManager/npcSelectionPanel/NPCPanel.qml`** (nouveau) — liste des visuels
  disponibles (modèles 3D + sprites) ; sélection → arme la pose d'un PNJ. Réutilise
  les composants `ASP_*` (grille/vignettes) et le kit `Meow*`.
- **`configPanel/npcConfigPanel/`** (nouveau) — panneau de config du PNJ
  sélectionné, sections préfixées `NCP_` (cohérent avec `CCP_`/`ZCP_`) :
  - `NCP_IdentitySection` — nom + choix visuel (modèle 3D vs sprite) + sélecteur.
  - `NCP_DialogueSection` — **éditeur de séquence** : liste de lignes avec add /
    remove / reorder (réutilise `MeowTextField`, `MeowButton`). Mutations via l'op
    `SetNpcParameter`.
  - `NCP_TriggerSection` — mode de trigger (`ComboBox`) + bouton **« Créer / lier la
    zone de proximité »** (visible si `Proximity`), qui crée une `PhysicZoneTile` par
    défaut autour du PNJ et la lie (`LinkItems`).
- **`meowComponent/snapable/SnapableNPC.qml`** (nouveau) — présentation 2D dans
  l'éditeur : sprite si `visualKind==Sprite2D` (réutilise le rendu de
  `SnapableDecoration`), sinon vignette/placeholder du modèle 3D. Sélectionnable /
  déplaçable comme les autres tiles.
- **`editor/logic/TileLogic.qml`** :
  - `placeSelectedAsset` (l.25-60) : brancher la pose PNJ (via
    `ItemSnapableFactory.createNPC()`), remplir `npcParameter` selon la sélection.
  - `createItemSnapableTile` (l.95-124) : router `NPCTile` → `SnapableNPC`.
  - À la pose d'un PNJ en mode `Proximity` : auto-créer + **lier** une zone trigger
    par défaut (option activable depuis le panneau).

### 4. Runtime 3D + dialogue (`qml/world3d/`)
- **`NPCDialogueController.qml`** (nouveau) — **copie du pattern
  `ScreenEffectController.qml`** : écoute `pattounxWorld.actorEnteredZone/ExitedZone`,
  résout `zoneId → tile de zone → tile PNJ liée (next/prev) → NPCParameter`, et pilote
  l'état du dialogue (séquence courante, index de ligne, pile pour zones
  chevauchantes). Filtre sur l'acteur local (`onlyActorId`).
- **`DialogueBox.qml`** (nouveau) — bulle 2D positionnée au-dessus du PNJ (position
  monde→écran via les helpers de `World3D`). Affiche la ligne courante, avance au
  clic/touche, se ferme en fin de séquence. Gère les 3 modes :
  - `Proximity` : ouverte tant que le joueur est dans la zone.
  - `Click` : détection de clic sur le node 3D (`HoverHandler`/pick) ou le sprite.
  - `Always` : bulle permanente (pancarte), sans avance.
- **`NPCSpawner.qml`** (nouveau) — instancie **un node 3D statique par NPCTile**
  (`SkinnedModel` en mode Model, billboard/plane texturé en mode Sprite), positionné
  depuis la position grille. **Pas de body physique** : c'est le *joueur* qui entre
  dans la zone, pas le PNJ — le PNJ n'a donc pas besoin d'un corps Pattounx, juste
  d'un node visuel figé.
- **`World3D.qml`** — instancier `NPCSpawner`, `NPCDialogueController` et le layer
  `DialogueBox`, câblés sur `snapableTilesList` + `pattounxWorld` (comme
  `ScreenEffectController`/`ScreenEffectOverlay` le sont déjà).
  **⚠ Risque technique n°1** : `World3D.qml` ne présente aujourd'hui qu'**un seul**
  `SkinnedModel` (le joueur) — il n'existe pas encore de mécanisme pour injecter N
  nodes. Il faudra exposer le node de scène et instancier un `Repeater3D`/couche NPC
  piloté par les NPCTiles. Lire `World3D.qml:1-200` (helpers de mapping, `entityNode`,
  projection monde→écran pour ancrer la bulle) avant de coder cette partie.

### 5. Automation / tests
- **`Editor.qml`** (`editorAutomationHooks`, l.2237-2530) : ajouter
  `placeNPC(visualKind, ref, gx, gy)` (+ éventuellement `setNpcDialogue`). Passe par
  le même chemin UI (`placeSelectedAsset`/`createNPC` + `Game.updateMap`) pour rester
  compatible collab/undo.
- Tool MCP optionnel `editor_place_npc` (miroir de `editor_place_item`), non bloquant V1.

---

## Découpage en phases (livrables testables)

- **Phase 1 — Backend + sérialisation** : `NPCParameter`, `NPCTile`, borne ctor JSON
  étendue, factory, `registerQml`, round-trip save/load. *Livrable : un PNJ posé
  programmatiquement survit à save→load.*
- **Phase 2 — Pose + config éditeur** : module `npc`, `NPCPanel`, `SnapableNPC`,
  routing `TileLogic`, panneau `NCP_*`. *Livrable : poser et configurer un PNJ à la souris.*
- **Phase 3 — Zone de trigger liée** : bouton « créer/lier zone » + auto-lien
  `LinkItems`, vérifier que la zone se déplace/reshape avec l'outil existant et reste
  liée. *Livrable : zone de proximité éditable et associée.*
- **Phase 4 — Runtime dialogue** : `NPCDialogueController` + `DialogueBox`, mode
  `Proximity` d'abord puis `Click` et `Always`. *Livrable : entrée dans la zone → la
  séquence s'affiche et s'avance.*
- **Phase 5 — Visuel 3D** : `NPCSpawner` + `SkinnedModel` pour `visualKind==Model3D`.
  *Livrable : PNJ 3D visible sur le plateau.*
- **Phase 6 — Collab/undo/automation** : op `SetNpcParameter` + remote apply, hook
  `placeNPC`, tests dual-instance. *Livrable : édition PNJ synchronisée entre deux instances.*

---

## Risques & pièges (issus du CLAUDE.md et de la mémoire)

- **Borne `TileType` du ctor JSON** (`ItemSnapable.cpp:61`) : oubli = tous les PNJ
  chargés retombent en `DecorationTile` silencieusement. À étendre en priorité.
- **Zones `exclusion=true` n'émettent pas enter/exit** : la zone de trigger doit être
  **non-exclusion** (`exclusion=false`) pour déclencher `actorEnteredZone` (cf.
  `EditorPhysicsBridge` l.138-140).
- **Binding QML sur `var`/liste** : muter `dialogueLines` en place ne notifie pas ;
  réassigner la liste entière (pattern `_stack.slice()` de `ScreenEffectController`).
- **`mapInfo`/tiles recréés** : `NPCDialogueController` doit re-résoudre sur
  changement de `snapableTilesList` (comme `onMapInfoChanged` recalcule dans
  `ScreenEffectController`).
- **Préservation du `ChatClient`** en collab (ne pas écraser celui du lobby).
- **Suppression en cascade** : supprimer un PNJ devrait aussi délier (voire supprimer)
  sa zone liée — politique à définir en Phase 3.
- **CMake `GLOB_RECURSE`** : reconfigurer après ajout de `npcparameter.cpp`.
- **Style** : toute valeur de style via le singleton `Theme` ; `pixelSize` (jamais
  `pointSize`) pour la bulle de dialogue.
- **Injection multi-node dans `World3D`** : mécanisme absent aujourd'hui (un seul
  `SkinnedModel`) → principal inconnu technique (cf. Phase 5).
- **Picking 3D (mode `Click`)** : vérifier l'existence d'un picking QtQuick3D
  (`View3D.pick`) dans le projet ; sinon fallback overlay 2D avec `TapHandler` ancré
  sur le PNJ.
- **World3D éditeur (preview) vs gameplay** : ce plan câble le dialogue dans le
  `World3D` de l'éditeur. Si le dialogue doit tourner en **partie réelle**, localiser
  le `World3D`/scène de gameplay (probablement distinct) et y répliquer le câblage —
  **à explorer** avant la Phase 4.
- **Audit des `switch(tileType)` / `tileType ===`** : après ajout de `NPCTile`,
  passer en revue tous les sites (`operator==`, remote-apply, gating de pose
  `Editor.qml`, `EditorPhysicsBridge`) pour couvrir la nouvelle valeur.

---

## Vérification (fin d'implémentation)

1. **Round-trip JSON** (Phase 1) : poser un PNJ via hook automation, sauver,
   recharger la map, vérifier `npcParameter` (nom, lignes, mode) intact.
2. **Parcours éditeur** (Phases 2-3) : module PNJ → poser → configurer nom + 3 lignes
   + mode Proximité → créer zone → déplacer/reshaper la zone → save/reload.
3. **In-game** (Phases 4-5) : lancer l'app, amener le joueur dans la zone → la
   séquence s'affiche, s'avance au clic, se ferme ; tester `Clic` et `Toujours
   visible` ; vérifier le PNJ 3D si modèle configuré.
4. **Collab** (Phase 6) : cible `dual_test_p2p` — éditer les lignes d'un PNJ sur
   l'instance 1, vérifier la propagation sur l'instance 2 ; undo/redo de la pose.

*(Pas de test runner automatisé — vérification manuelle via l'exécutable + serveur d'automation.)*

---

## État d'implémentation (2026-07-01)

Phases 1-6 implémentées. Fichiers livrés :

- **C++** : `cpp/game/item_snapable/npcparameter.{h,cpp}` (toJSON via
  `QJsonDocument`, `applyJson` **Q_INVOKABLE** pour le remote-apply QML) ;
  `ItemSnapable` étendu (enum `NPCTile`, `Q_PROPERTY npcParameter`, borne ctor
  JSON, toJSON/applyJson/operator==, registerQml) ;
  `ItemSnapableFactory::createNPC()` ; `EditorOpType::SetNpcParameter = 17` +
  `EditorOpBus::makeSetNpcParameterOp`.
- **Éditeur QML** : module `"npc"` (🎭) dans `ModuleManager` ;
  `moduleManager/npcSelectionPanel/{NPCPanel,NPC_Content}.qml` (identité +
  trigger + bouton « Poser un PNJ » → `logic.armNpcPose`) ;
  `configPanel/npcConfigPanel/{NPCConfigurationPanelSection,NCP_Identity,
  NCP_Dialogue,NCP_Trigger}Section.qml` branché dans `BottomSidePanel`
  (module "config", alimenté par `updateSidePanel` sur sélection simple) ;
  `meowComponent/snapable/SnapableNPC.qml` ; routage `TileLogic`
  (`npcPoseArmed` prioritaire dans `placeSelectedAsset`,
  `createItemSnapableTile` → `snapableNPCComponent`).
- **Runtime** : `world3d/NPCDialogueController.qml` (pattern
  ScreenEffectController, résolution zoneId → `getPrevList()` → PNJ),
  `world3d/DialogueBox.qml`, `world3d/NPCDialogueOverlay.qml`,
  `world3d/NPCSpawner.qml`, câblés dans `Editor.qml` (workArea).
- **Automation** : hooks `placeNPC(visualKind, ref, gx, gy, options)` et
  `setNpcDialogue(uuid, lines)` dans `editorAutomationHooks`.

Écarts assumés par rapport au plan initial :

1. **Bulle en 2D workArea, pas en projection 3D→écran** : les tiles PNJ vivent
   dans `workArea` ; ancrer `DialogueBox` sur `tile.x/tile.y` suit pan/zoom
   gratuitement. Le mécanisme « injecter N nodes dans World3D » (risque n°1 du
   plan) se réduit à un `Instantiator` de `Node` parentés à `world3D.scene`
   (NPCSpawner).
2. **Sprite 2D non répliqué en 3D** : le plateau 2D est visible sous la View3D
   transparente ; `NPCSpawner` ne spawne que les PNJ `Model3D`. Billboard 3D
   à faire si besoin plus tard.
3. **Mode Clic = badge 💬 flottant** au-dessus de la tile (dans l'overlay),
   pas de picking QtQuick3D — évite tout conflit avec les MouseAreas de
   sélection de l'éditeur.
4. **Lien PNJ↔zone via `connectionManager.addNextElement` +
   `Game.updateMap(TileModified)`** (chemin UI existant, transporté par
   `ApplyState` en collab) plutôt qu'une op `LinkItems` explicite.
5. **Pas d'undo dédié sur la config PNJ** (comme les player profiles v1) ;
   la pose/suppression passe par le chemin standard donc undo OK.
6. **Suppression en cascade non faite** : supprimer un PNJ laisse sa zone liée
   orpheline (politique à définir, cf. risques).
7. **Avance clavier non câblée** (`advanceOnClick` sérialisé mais seule
   l'avance au clic est implémentée en V1).
