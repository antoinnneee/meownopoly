# 05 — Espace mémoire par `snapableElement`

> **Statut : cadrage (draft).** Repose sur une cartographie vérifiée du pipeline
> `ItemSnapable` / `EditDelta` / `EditorOpBus`. **Vérifier les numéros de ligne
> contre le code avant d'implémenter** (ils dérivent).

## 1. Objectif

Donner à **chaque élément posable** (`ItemSnapable`) un **espace mémoire** : un
**set de paramètres typés** (`int`, `string`, `bool`, `real`, …) — des
**variables** attachées à l'élément, sans schéma de clés imposé côté cœur, que
l'IA du joueur lit et écrit pour **personnaliser** l'élément (« loyer ×2 », état,
compteur, paramètres d'un comportement, référence à un artefact QML de la doc 04).

Ces variables ont **trois usages liés** :

1. **Transport / broadcast gratuit.** Elles voyagent dans le **delta de sync de la
   map** (`EditDelta` / `ApplyState`) déjà existant → persistées, undoables et
   **broadcastées** aux autres joueurs **sans nouveau canal** (§2). Ce sont, de
   fait, les **variables de partie synchronisées**.
2. **Support des règles custom, notamment sur les zones.** Une zone (d'exclusion /
   d'effet) ou toute tuile porte des variables que la logique de partie exploite :
   la mémoire d'une zone devient l'**état lisible/modifiable d'une règle** (ex.
   « multiplicateur de loyer de cette zone », « nombre de passages »).
3. **Réactivité par signaux QML.** Une écriture émet un **signal QML** que les
   comportements générés / règles custom (doc 04/06) **écoutent** pour réagir
   (`onUserMemoryChanged`). C'est le **point de couplage** entre la donnée
   synchronisée et le JS embarqué : une règle réagit à un changement de variable,
   qu'il vienne d'une écriture locale **ou** d'un broadcast distant (§4).

La **base** de l'élément reste identique ; le nouvel ensemble **base + mémoire**
s'intègre au **système de delta** de `@game/map` (persistance, undo/redo, sync
collab) **sans modifier le pipeline ni ouvrir un nouveau canal**.

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
Dans `ItemSnapable` : ajouter le **conteneur de variables typées** + son **API QML
réactive**.

- **Conteneur typé** : `QVariantMap m_userMemory`. Préférer `QVariantMap` à un
  `QJsonObject` brut : il **préserve les types natifs** (`int`/`string`/`bool`/
  `real`) côté QML, s'accède comme un objet JS, et se convertit dans les deux sens
  (`QJsonObject::fromVariantMap` / `QJsonValue::toVariant`).
- **Q_PROPERTY réactive** : `Q_PROPERTY(QVariantMap userMemory READ userMemory
  WRITE setUserMemory NOTIFY userMemoryChanged)`. Le **signal `userMemoryChanged`
  est essentiel** — c'est le support de l'**usage 3** (§1) : règles custom et
  comportements générés s'y abonnent. Prévoir aussi un setter fin `Q_INVOKABLE
  setMemoryValue(const QString &key, const QVariant &value)` qui émet le signal
  (idéalement un `memoryValueChanged(key)` en plus, pour un réveil **ciblé** par
  clé sans re-scanner tout le map).
- **`toJSON()`** : insérer une clé `"memory": <blob>`. ⚠️ **Piège n°1 :**
  `ItemSnapable::toJSON()` est aujourd'hui de la **concaténation manuelle de
  chaînes**, pas du `QJsonDocument`. Pour des valeurs arbitraires (guillemets,
  `\n`, Unicode), il **faut** sérialiser via
  `QJsonDocument(QJsonObject::fromVariantMap(m_userMemory)).toJson(Compact)` et
  l'injecter proprement — sinon échappement cassé. C'est le seul vrai risque
  technique de cette brique.
- **ctor JSON** : `m_userMemory = json["memory"].toObject().toVariantMap()` (aucun
  schéma de clés imposé).
- **`applyJson()`** : `if (json.contains("memory")) setUserMemory(json["memory"].
  toObject().toVariantMap())`. C'est ce qui fait fonctionner automatiquement le
  **Pattern B** (`ApplyState` → `applyDelta` → `applyJson`) **et** — parce que
  `setUserMemory` émet `userMemoryChanged` — ce qui déclenche les règles custom
  **sur réception d'un broadcast distant**, pas seulement sur écriture locale (§4).
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
- **Réactivité vs boucle** : `setUserMemory`/`applyJson` émettent
  `userMemoryChanged` ; une règle custom qui, **en réaction**, ré-écrit la mémoire
  peut boucler (écriture → signal → écriture). Réutiliser le garde
  `beginApplyRemote/endApplyRemote` déjà en place pour les ops distantes dans
  `Editor.qml`, et/ou ne ré-émettre que sur changement réel de valeur.
- **Types supportés** : borner aux **primitives sérialisables** (`int`, `real`,
  `string`, `bool`, listes/objets imbriqués de ces types). Pas de `QObject`, de
  fonction ni de handle vivant dans le map — non sérialisable, ne passe pas le
  delta et casse la sync.
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
  "data": { "rentMultiplier": 2 },   // les VARIABLES typées (le gros du besoin)
  "behavior": { "qmlRef": "…", "params": {…} }, // réf. artefact QML (doc 04)
  "tags": ["water-adjacent"]         // libellés pour les règles
}
```

Le cœur ne connaît que `memory` (un `QVariantMap` de valeurs typées) ; le sens de
`schema`/`data`/`behavior`/`tags` est une convention de la couche IA/règles. Les
**variables de partie** (usage 1/2 du §1) vivent sous `data` ; c'est ce que les
règles custom lisent et écrivent, et sur quoi elles s'abonnent via
`userMemoryChanged`.

## 6. Questions ouvertes (→ doc 08)

- Blob **global à la tuile** (proposé) ou **par sous-paramètre** (un `memory` dans
  chaque `*Parameter`) ? Le global est plus simple et suffit a priori.
- Merge vs replace pour l'op fine C.
- Faut-il exposer l'espace mémoire aussi sur les entités **non-tuiles**
  (`PlayerProfile`, `MapInfo`) ?
- Plafond de taille du blob et politique en cas de dépassement.
