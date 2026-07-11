# 05 — Espace mémoire par `snapableElement`

> **Statut : cadrage (draft).** Repose sur une cartographie du pipeline
> `ItemSnapable` / `EditDelta` / `EditorOpBus` (persistance + undo) **et** de
> `PhysicsSession` (stream live). **Vérifier les numéros de ligne contre le code
> avant d'implémenter** (ils dérivent).

## 1. Objectif

Donner à **chaque élément posable** (`ItemSnapable`) un **espace mémoire** : un
**set de valeurs sérialisables** (`int`, `string`, `bool`, `real`, listes/objets)
attachées à l'élément, sans schéma de clés métier imposé côté cœur, que
l'IA du joueur lit et écrit pour **personnaliser** l'élément (« loyer ×2 », état,
compteur, paramètres d'un comportement, référence à un artefact QML de la doc 04).

Le cadrage distingue deux classes de données qui ne doivent plus être confondues :

- **configuration durable** : paramètres issus d'un geste d'édition ou d'une
  proposition acceptée, persistés dans la map et undoables avec cette transaction ;
- **état runtime** : compteurs, cooldowns et état vivant d'une partie, autoritatifs
  chez l'hôte, répliqués avec une sémantique « dernier état » et non undoables au
  grain de chaque écriture.

Ces valeurs ont **trois usages liés** :

1. **Deux chemins selon la sémantique.** La configuration durable emprunte
   `ApplyState`/`EditDelta`. Seul l'état runtime emprunte un flux
   host-authoritative inspiré de `PhysicsSession`. Une écriture cliente est une
   intention ; l'hôte valide/applique puis publie le nouvel état.
2. **Support des règles custom, notamment sur les zones.** Une zone (d'exclusion /
   d'effet) ou toute tuile porte des variables que la logique de partie exploite :
   la mémoire d'une zone devient l'**état lisible/modifiable d'une règle** (ex.
   « multiplicateur de loyer de cette zone », « nombre de passages »).
3. **Réactivité par signaux QML.** Une écriture émet un **signal QML** que les
   comportements générés / règles custom (doc 04/06) **écoutent** pour réagir
   (`onUserMemoryChanged`). C'est le **point de couplage** entre la donnée
   synchronisée et le JS embarqué : une règle réagit à un changement de variable,
   qu'il vienne d'une écriture locale **ou** d'un snapshot distant (§4).

**Undo au grain de la transaction d'auteur, jamais au grain du tick.** L'ajout
d'un artefact et ses changements de configuration durable forment une transaction
undoable. L'état runtime concurrent n'est pas restauré : un snapshot global ferait
revenir en arrière des événements sans rapport et créerait des divergences en
collaboration. La compensation ciblée exacte reste à cadrer (§3, Étape C).

La **base** de l'élément reste identique. Trois chemins sont distingués : op
d'édition (configuration durable et undo), `toJSON()` (persistance), et flux
runtime host-authoritative (état vivant). Leur représentation physique peut être
commune, mais leur sémantique ne l'est pas.

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

**Point clé (persistance & undo de configuration, PAS le runtime) :** `EditDelta.before/
after` étant déjà le `toJSON()` **complet** de la tuile, tout champ ajouté à
`toJSON()`/`applyJson()` **voyage gratuitement** par la **persistance disque** et
peut servir d'inverse à une transaction de configuration (Étape C). En revanche,
on **ne fait pas** transiter l'état runtime haute fréquence par `ApplyState` :
cela saturerait les piles undo et le canal d'ops.

### 2.3 Le stream physique (`PhysicsSession`) — inspiration, pas contrat copié
`cpp/game/physics/physics_session.{h,cpp}` : host-authoritative, broadcast de
**snapshots à 30 Hz** (reliable, plage `physics_message_type.h` 0x40+), les clients
routant leurs inputs vers l'hôte qui simule pour tous. La mémoire partage avec
la physique l'autorité hôte et le routage des intentions, mais pas nécessairement
sa cadence ni son transport. « Reliable » décrit la livraison ; « dernier état »
signifie que les versions intermédiaires peuvent être coalescées/supplantées. Il
faut éviter une file fiable qui rejouerait des états devenus obsolètes. Nouveau
message dédié, extension du protocole physique, delta ou snapshot restent à
trancher et à budgéter (doc 09).

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
  l'injecter proprement — sinon échappement cassé. C'est un risque de
  sérialisation important, aux côtés des risques de concurrence et de transport.
- **ctor JSON** : `m_userMemory = json["memory"].toObject().toVariantMap()` (aucun
  schéma de clés imposé).
- **`applyJson()`** : `if (json.contains("memory")) setUserMemory(json["memory"].
  toObject().toVariantMap())`. Sert au **chargement disque** et à l'application
  d'un inverse de configuration (Étape C). Comme `setUserMemory` émet
  `userMemoryChanged`, la restauration réveille aussi les comportements (§4).
- **`operator==`** : inclure le blob si l'on veut que les no-op (before==after)
  soient détectés correctement.

### Étape B — Sync de l'état runtime via autorité hôte
Le sync de l'**état runtime** ne passe pas par `ApplyState`/`EditDelta`. Il
s'inspire du modèle `PhysicsSession` (§2.3) :
- l'hôte est **autoritatif** sur les valeurs ; un script client qui écrit une
  variable **route l'intention vers l'hôte** (comme un input physique), l'hôte
  applique et publie une mise à jour mémoire coalesçable ;
- réception : `setUserMemory` sur la tuile ciblée → émet `userMemoryChanged` →
  réveille scripts/règles (usage 3, §1). **Pas** de passage par `applyDelta` (donc
  pas d'historisation).
- **non-undoable** au grain de l'écriture : c'est de l'état, pas une édition.
  Le choix reliable/raw et la cadence ne sont pas encore décidés.

À trancher (doc 08) : message `MemorySnapshot` **dédié** vs **extension** du snapshot
physique ; **delta par-clé** vs snapshot complet par tuile ; débit et plafond.

### Étape C — Transaction structurelle et compensation ciblée
Une proposition acceptée doit déclarer son **write-set durable** : artefacts créés,
tuiles modifiées et clés de configuration touchées. Ce write-set alimente l'inverse
undoable existant. L'undo retire l'artefact et restaure uniquement la configuration
durable appartenant à la transaction. Il ne restaure pas l'état runtime global.

Restent à trancher : conflits si une clé a été remodifiée depuis, comportement du
redo, et politique en cours de partie collaborative. Un snapshot global de toute
la mémoire n'est plus recommandé.

**Recommandation :** Étape A d'abord (modèle + persistance), puis prototyper
séparément B (runtime) et C (transaction durable) avec des tests de concurrence.

## 4. Contraintes & pièges

- **Taille du flux** : un gros blob envoyé périodiquement est coûteux.
  Privilégier un **delta par-clé** (n'émettre que les variables changées) plutôt
  qu'un snapshot complet par tuile, et **plafonner** la taille (cf. sandbox
  doc 04 §3.4), coalescer et ne publier qu'en cas de changement.
- **Pas de schéma métier côté cœur** : le C++ traite les valeurs comme opaques. Le
  **sens** des clés est une **convention IA / comportements** (doc 06), pas du C++.
  préserve la liberté (point central du pivot) tout en gardant le cœur stable.
- **Undo** : ne pas router les écritures d'état runtime par
  `submitOpWithUndo`/`ApplyState`. Les écritures de **configuration durable**, elles,
  doivent appartenir à la transaction d'édition correspondante.
- **Réactivité vs boucle** : `setUserMemory`/`applyJson` émettent
  `userMemoryChanged` ; une règle custom qui, **en réaction**, ré-écrit la mémoire
  peut boucler (écriture → signal → écriture). Le garde
  `beginApplyRemote/endApplyRemote` des ops n'est pas suffisant pour ce nouveau
  bus : prévoir version d'écriture, garde de réentrance, budget de cascade et
  absence d'émission si la valeur n'a pas réellement changé.
- **Types supportés** : borner aux **primitives sérialisables** (`int`, `real`,
  `string`, `bool`, listes/objets imbriqués de ces types). Pas de `QObject`, de
  fonction ni de handle vivant dans le map — non sérialisable, ne passe pas le
  delta et casse la sync.
- **Sécurité** : si le blob **référence ou contient du QML** (comportement
  généré), ce QML **ne doit jamais** être instancié sans passer par le sandbox
  (doc 04). Le blob sur disque n'est **pas** de confiance : re-valider au
  chargement.

## 5. Conventions d'usage (proposition, non normatif côté cœur)

Pour que l'IA et les comportements de règles se comprennent, recommander (sans
l'imposer en C++) une structure :

```jsonc
"memory": {
  "schema": 1,                       // versionnage de la convention
  "config": { "rentMultiplier": 2 }, // configuration durable/undoable
  "state": { "passages": 0 },         // état runtime, persistance à décider
  "behavior": { "qmlRef": "…", "params": {…} }, // réf. artefact QML (doc 04)
  "tags": ["water-adjacent"]         // libellés pour les règles
}
```

Le cœur ne connaît que `memory` ; le sens métier reste une convention. En revanche,
la distinction de sémantique `config`/`state` doit être comprise par la couche de
transport afin de ne pas envoyer chaque tick dans l'undo ni de persister un état
éphémère par accident. Le nom final de ces namespaces reste à valider.

## 6. Questions ouvertes (synthèse doc 08 ; questionnaire exhaustif doc 09)

- Blob **global à la tuile** (proposé) ou **par sous-paramètre** (un `memory` dans
  chaque `*Parameter`) ? Le global est plus simple et suffit a priori.
- Frontière exacte **configuration durable / état runtime** et persistance de
  l'état lors d'une sauvegarde/reprise de partie.
- **Transport du runtime** (Étape B) : protocole dédié vs extension physique ;
  delta/snapshot, coalescence, fiabilité, cadence et plafond.
- **Transaction d'undo** (Étape C) : déclaration du write-set, conflits et redo.
- Faut-il exposer l'espace mémoire aussi sur les entités **non-tuiles**
  (`PlayerProfile`, `MapInfo`) ?
- Plafond de taille du blob et politique en cas de dépassement.
