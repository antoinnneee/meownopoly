# 05 — Espace mémoire par `snapableElement`

> **Statut : cadrage (draft).** Repose sur une cartographie du pipeline
> `ItemSnapable` / `EditDelta` / `EditorOpBus` (persistance + snapshot) **et** de
> `PhysicsSession` (stream live). **Vérifier les numéros de ligne contre le code
> avant d'implémenter** (ils dérivent).

## 1. Objectif

Donner à **chaque élément posable** (`ItemSnapable`) un **espace mémoire** : un
**set de paramètres typés** (`int`, `string`, `bool`, `real`, …) — des
**variables** attachées à l'élément, sans schéma de clés imposé côté cœur, que
l'IA du joueur lit et écrit pour **personnaliser** l'élément (« loyer ×2 », état,
compteur, paramètres d'un comportement, référence à un artefact QML de la doc 04).

Ces variables ont **trois usages liés** :

1. **Stream host-authoritative, comme les états de physique.** Ces variables
   changent à la **fréquence du runtime de gameplay** (une variable peut muter à
   chaque tick), pas à celle d'une édition. On les **streame donc comme les
   snapshots physiques** (`PhysicsSession`, host-authoritative : l'hôte applique
   puis rebroadcaste), **pas** via l'op d'édition undoable `ApplyState`/`EditDelta`
   (§2). Conséquence assumée : le stream mémoire est **lossy et non-undoable au
   grain de l'écriture** — c'est de l'**état de partie**, pas une édition. Ce sont,
   de fait, les **variables de partie synchronisées** que les scripts QML/JS
   (doc 04) lisent et écrivent pour construire le jeu.
2. **Support des règles custom, notamment sur les zones.** Une zone (d'exclusion /
   d'effet) ou toute tuile porte des variables que la logique de partie exploite :
   la mémoire d'une zone devient l'**état lisible/modifiable d'une règle** (ex.
   « multiplicateur de loyer de cette zone », « nombre de passages »).
3. **Réactivité par signaux QML.** Une écriture émet un **signal QML** que les
   comportements générés / règles custom (doc 04/06) **écoutent** pour réagir
   (`onUserMemoryChanged`). C'est le **point de couplage** entre la donnée
   synchronisée et le JS embarqué : une règle réagit à un changement de variable,
   qu'il vienne d'une écriture locale **ou** d'un snapshot distant (§4).

**Undo au grain « structurel », pas au grain « variable ».** Puisque le stream
mémoire n'est pas undoable, l'undo est préservé à une granularité plus grossière :
**avant chaque ajout d'un item QML**, on capture un **snapshot de la mémoire de
tous les éléments**. Défaire l'ajout = retirer l'item **et** restaurer ce snapshot.
L'undo reste ainsi fonctionnel **sur une session de gameplay**, sans historiser
chaque écriture de variable (§3, Étape C).

La **base** de l'élément reste identique. Deux transports **distincts** portent la
mémoire : le **stream physique** (sync live, §2.3) et le **`toJSON()`** (persistance
disque + snapshot d'undo, §2.2) — pas l'op d'édition undoable pour le live.

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

**Point clé (persistance & snapshot d'undo, PAS le live) :** `EditDelta.before/
after` étant déjà le `toJSON()` **complet** de la tuile, tout champ ajouté à
`toJSON()`/`applyJson()` **voyage gratuitement** par la **persistance disque** et
sert de base au **snapshot d'undo** (Étape C). En revanche, on **ne fait pas**
transiter le *stream temps réel* de la mémoire par `ApplyState` : à la fréquence du
gameplay, cela **saturerait les piles undo et le canal d'ops**. Le live passe par
le mécanisme **physique** (ci-dessous).

### 2.3 Le stream physique (`PhysicsSession`) — socle du sync mémoire live
`cpp/game/physics/physics_session.{h,cpp}` : host-authoritative, broadcast de
**snapshots à 30 Hz** (reliable, plage `physics_message_type.h` 0x40+), les clients
routant leurs inputs vers l'hôte qui simule pour tous. C'est **exactement** le
profil du sync mémoire : état de partie à fréquence runtime, autoritatif hôte,
lossy, non-undoable. Le sync de l'espace mémoire **réutilise ce modèle** — nouveau
message `MemorySnapshot` dédié **ou** extension du snapshot physique (à trancher,
doc 08). Un script client qui écrit une variable **route l'intention vers l'hôte**
(comme un input physique) ; l'hôte applique et **rebroadcaste**.

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
  toObject().toVariantMap())`. Sert au **chargement disque** et à la **restauration
  d'un snapshot d'undo** (Étape C). Comme `setUserMemory` émet `userMemoryChanged`,
  la restauration réveille aussi les règles (§4). *(L'application d'un snapshot de
  stream live emprunte un chemin analogue — `setUserMemory` sur la tuile ciblée —
  mais pas via `applyDelta`, cf. Étape B.)*
- **`operator==`** : inclure le blob si l'on veut que les no-op (before==after)
  soient détectés correctement.

### Étape B — Sync live via stream host-authoritative (comme la physique)
Le sync live de la mémoire **ne passe pas** par `ApplyState`/`EditDelta`. Il
réutilise le modèle `PhysicsSession` (§2.3) :
- l'hôte est **autoritatif** sur les valeurs ; un script client qui écrit une
  variable **route l'intention vers l'hôte** (comme un input physique), l'hôte
  applique et **rebroadcaste un snapshot mémoire** (~30 Hz, reliable).
- réception : `setUserMemory` sur la tuile ciblée → émet `userMemoryChanged` →
  réveille scripts/règles (usage 3, §1). **Pas** de passage par `applyDelta` (donc
  pas d'historisation).
- **lossy & non-undoable** assumés : c'est de l'état, pas une édition.

À trancher (doc 08) : message `MemorySnapshot` **dédié** vs **extension** du snapshot
physique ; **delta par-clé** vs snapshot complet par tuile ; débit et plafond.

### Étape C — Undo par snapshot avant ajout d'un item QML
Pour garder l'undo **fonctionnel sur une session de gameplay** malgré le stream
non-undoable :
- **avant** chaque **ajout d'un item QML** (changement structurel), capturer un
  **snapshot de la mémoire de tous les éléments** (les `toJSON()` des blobs) et le
  pousser sur la pile d'undo, **attaché à l'op d'ajout** ;
- **undo** de l'ajout = retirer l'item **et** restaurer le snapshot mémoire (via
  `applyJson` sur chaque tuile) ; **redo** = ré-ajouter + ré-appliquer l'état
  post-ajout ;
- granularité = **le geste structurel**, pas l'écriture de variable — suffisant pour
  « annuler l'ajout d'un élément de gameplay » sans historiser chaque tick.

À trancher (doc 08) : snapshot **global** (toute la carte) vs **ciblé** (éléments
impactés) ; coût mémoire/taille ; articulation avec l'undo d'édition classique
(hors session de gameplay).

**Recommandation :** Étape A d'abord (modèle + persistance/`toJSON`), puis **B et C
ensemble** — livrer B sans C **casse l'undo** en session de gameplay.

## 4. Contraintes & pièges

- **Taille en stream** : à ~30 Hz, un gros blob **par tick** est coûteux.
  Privilégier un **delta par-clé** (n'émettre que les variables changées) plutôt
  qu'un snapshot complet par tuile, et **plafonner** la taille (cf. sandbox
  doc 04 §3.4). Le snapshot d'undo (Étape C), lui, est ponctuel (par ajout d'item),
  pas par tick.
- **Pas de schéma côté cœur** : le C++ traite le blob comme opaque. Le **sens** des
  clés est une **convention IA / moteur de règles** (doc 06), pas du code C++. Ça
  préserve la liberté (point central du pivot) tout en gardant le cœur stable.
- **Undo** : le stream mémoire n'est **pas** undoable (Étape B) ; l'undo repose sur
  le **snapshot avant ajout d'item QML** (Étape C). Ne **pas** router les écritures
  de variables par `submitOpWithUndo`/`ApplyState` — cela saturerait la pile et le
  canal d'ops.
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
- **Transport du stream** (Étape B) : message `MemorySnapshot` dédié vs extension du
  snapshot physique ; **delta par-clé** vs snapshot complet ; débit/plafond.
- **Snapshot d'undo** (Étape C) : **global** (toute la carte) vs **ciblé** ; coût
  taille/mémoire ; articulation avec l'undo d'édition classique.
- Faut-il exposer l'espace mémoire aussi sur les entités **non-tuiles**
  (`PlayerProfile`, `MapInfo`) ?
- Plafond de taille du blob et politique en cas de dépassement.
