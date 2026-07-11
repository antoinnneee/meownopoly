# 05 — Espace mémoire par `snapableElement`

> **Statut : cadrage (draft).** Repose sur une cartographie vérifiée du pipeline
> `ItemSnapable` / `EditDelta` / `EditorOpBus`. **Vérifier les numéros de ligne
> contre le code avant d'implémenter** (ils dérivent).

## 1. Objectif

Donner à **chaque élément posable** (`ItemSnapable`) un **espace mémoire libre** :
un blob JSON arbitraire, sans schéma imposé côté cœur, que l'IA du joueur écrit
pour **personnaliser** l'élément (données custom : « loyer ×2 », état, paramètres
d'un comportement, référence à un artefact QML de la doc 04). La **base** de
l'élément reste identique ; le nouvel ensemble **base + mémoire** doit s'intégrer
au **système de delta** de `@game/map` (persistance, undo/redo, sync collab)
**sans nouveau canal**.

## 2. État des lieux du pipeline (socle réutilisé)

### 2.1 `ItemSnapable` (base)
`cpp/game/item_snapable/ItemSnapable.{h,cpp}`. Identité `QUuid m_uniqueId` ;
`TileType` ; sous-objets de paramètres (`DisplayParameter`, `DecorationParameter`,
`ZoneParameter`, `NPCParameter`, `EnemyParameter`, `PhysicalObjectParameter`,
`Case*`). Sérialisation `toJSON()` (clés `uniqueId`, `tileType`, `*Parameter`
conditionnés au type, `next`/`prev`) ; patch partiel `applyJson()` (n'écrase
jamais `uniqueId`).

### 2.2 Le « delta manager » (@game/map) — **deux mécanismes chaînés**
- **`EditDelta` + piles undo/redo** (`cpp/game/map/editdelta.h`, `map.cpp`) :
  `{type ∈ {TileModified, TileAdded, TileDeleted, MetadataChanged}, tileId,
  groupId, before, after}`. `before`/`after` sont les **JSON complets de la
  tuile** (`toJSON()`), pas des patchs de champ. `Map::applyDelta` applique via
  `tile->applyJson(state)`.
- **`EditorOpBus`/`EditorSession`** (`cpp/editor/ops/`, `cpp/editor/network/`) :
  transport collaboratif. `Game::updateMap` pousse le delta **et** le ré-emballe
  en op **`ApplyState` (=11)** pour le réseau. En réception,
  `Game::applyRemoteDelta` ré-applique **sans** re-historiser.

**Point clé :** `EditDelta.before/after` étant déjà le `toJSON()` **complet** de la
tuile, tout champ ajouté à `toJSON()`/`applyJson()` **voyage gratuitement** par
la persistance disque, l'undo/redo local **et** le broadcast `ApplyState`. C'est
la voie de moindre effort pour l'espace mémoire.

## 3. Stratégie d'intégration (recommandée)

### Étape A — Modèle C++ (obligatoire)
Dans `ItemSnapable` : ajouter `QJsonObject m_userMemory` + `Q_PROPERTY userMemory`
(lisible/écrivable QML) + setter/getter `Q_INVOKABLE`.

- **`toJSON()`** : insérer une clé `"memory": <blob>`. ⚠️ **Piège n°1 :**
  `ItemSnapable::toJSON()` est aujourd'hui de la **concaténation manuelle de
  chaînes**, pas du `QJsonDocument`. Pour un blob arbitraire (guillemets, `\n`,
  Unicode), il **faut** sérialiser le blob via `QJsonDocument(...).toJson(Compact)`
  et l'injecter proprement — sinon échappement cassé. C'est le seul vrai risque
  technique de cette brique.
- **ctor JSON** : parser `json["memory"]` tel quel (aucun schéma).
- **`applyJson()`** : `if (json.contains("memory")) setUserMemory(...)`. C'est ce
  qui fait fonctionner automatiquement le **Pattern B** (`ApplyState` →
  `applyDelta` → `applyJson`).
- **`operator==`** : inclure le blob si l'on veut que les no-op (before==after)
  soient détectés correctement.

### Étape B — Sync « gratuite » (aucun code réseau)
Une fois A fait : la persistance (`snapableTiles`), l'undo/redo (`map.cpp`
`applyDelta`) et le broadcast collab (`Game::updateMap` → `submitFromDelta` →
`ApplyState`) transportent le blob **sans modification**. On écrit le blob côté
QML puis on déclenche `Game.updateMap(EditDelta.TileModified, tile.snapableParameters, txId)`
comme n'importe quelle édition.

### Étape C — Op fine dédiée (optionnelle, si édition haute fréquence)
Si l'IA édite le blob très souvent, re-broadcaster **toute** la tuile via
`ApplyState` est lourd. Ajouter alors une op ciblée :
- `SetItemMemory = 20` dans `cpp/editor/ops/editor_op_type.h` (**rester la valeur
  la plus haute** — contrainte de `isEditorPacket`),
- helper `makeSetItemMemoryOp(uuid, blob)` dans `editor_op_bus.{h,cpp}` (calqué sur
  `makeSetNpcParameterOp`),
- `case SetItemMemory` dans le `switch` de remote-apply de `Editor.qml` (calqué sur
  `SetNpcParameter`), en tranchant **merge partiel vs remplacement** du blob.

**Recommandation :** livrer **A + B d'abord** (valeur immédiate, risque minimal),
n'ajouter **C** que si un besoin de perf le justifie.

## 4. Contraintes & pièges

- **Taille réseau** : un blob peut être gros. Le pipeline gère déjà le batch
  (~30 KB, `editor_op_bus`) et le chunking (~20 KB, `editor_session`) ; un gros
  blob passe par le chunking mais il faut **plafonner** la taille (cf. sandbox
  doc 04 §3.4).
- **Pas de schéma côté cœur** : le C++ traite le blob comme opaque. Le **sens** des
  clés est une **convention IA / moteur de règles** (doc 06), pas du code C++. Ça
  préserve la liberté (point central du pivot) tout en gardant le cœur stable.
- **Undo collab** : via B, l'undo passe par les piles `EditDelta` (déjà géré). Via
  C, prévoir l'op inverse si on veut `submitOpWithUndo`.
- **Sécurité** : si le blob **référence ou contient du QML** (comportement
  généré), ce QML **ne doit jamais** être instancié sans passer par le sandbox
  (doc 04). Le blob sur disque n'est **pas** de confiance : re-valider au
  chargement.

## 5. Conventions d'usage (proposition, non normatif côté cœur)

Pour que l'IA et le futur moteur de règles se comprennent, recommander (sans
l'imposer en C++) une structure :

```jsonc
"memory": {
  "schema": 1,                       // versionnage de la convention
  "data": { "rentMultiplier": 2 },   // données custom (le gros du besoin)
  "behavior": { "qmlRef": "…", "params": {…} }, // réf. artefact QML (doc 04)
  "tags": ["water-adjacent"]         // libellés pour les règles
}
```

Le cœur ne connaît que `memory` (blob opaque) ; `schema`/`data`/`behavior`/`tags`
sont une convention de la couche IA/règles.

## 6. Questions ouvertes (→ doc 08)

- Blob **global à la tuile** (proposé) ou **par sous-paramètre** (un `memory` dans
  chaque `*Parameter`) ? Le global est plus simple et suffit a priori.
- Merge vs replace pour l'op fine C.
- Faut-il exposer l'espace mémoire aussi sur les entités **non-tuiles**
  (`PlayerProfile`, `MapInfo`) ?
- Plafond de taille du blob et politique en cas de dépassement.
