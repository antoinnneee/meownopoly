# Analyse du système Undo/Redo de l'éditeur

> Audit réalisé le 2026-06-13 (branche `V2Antoine`). État du code au moment de l'analyse.

## Constat central : deux systèmes d'undo, un seul réellement branché

L'éditeur embarque **deux** mécanismes d'annulation distincts. Seul le premier est
câblé sur le clavier ; le second se remplit mais n'est jamais déclenché.

| | **Système A** — `Map` / `EditDelta` | **Système B** — `EditorOpBus` |
|---|---|---|
| Structures | `QStack<EditDelta> m_undoStack / m_redoStack` (`map.cpp:200`) | `QList<UndoEntry{op, inverseOp}>` (`editor_op_bus.cpp:132`) |
| Contenu | `before` / `after` JSON complet par tuile | op + inverse calculé à la main |
| Déclencheur clavier | **Ctrl+Z/Y → `Game.askPreview/askNext` → `Map::undo/redo`** (`EditorController.qml:81,89`) | **aucun** |
| Couverture | TileAdded / TileDeleted / **TileModified** / MetadataChanged | CreateItem ↔ DeleteItem, LinkItems ↔ UnlinkItems |
| Collab | `broadcastLastBatch` → `submitFromDelta(applyBefore)` (`game_loader.cpp:221`) | `submitOp(inverseOp)` |
| Appelé en pratique | Oui, c'est le *workhorse* | `submitOpWithUndo` oui (Link/Unlink) ; `undo()/redo()` **jamais** |

Vérification par grep : `EditorOpBus.undo()` / `redo()` ne sont appelés **nulle part**
en QML. Seul `submitOpWithUndo` l'est, depuis
`ConnectionsConfigurationSection.qml:238,290`. La pile B se remplit (sur link/unlink)
mais **rien ne la déclenche** → code mort fonctionnel.

---

## Flux réel (système A)

### Monoposte
```
Ctrl+Z
  → EditorController.qml:89  (intercept Key_Z + Ctrl)
  → Game.askPreview()        (game_loader.cpp:214)
  → Map::undo()              (map.cpp:376)  pop groupe → applyDelta(applyBefore=true)
  → mutations QML locales
```

### Collaboratif
```
Ctrl+Z
  → Game.askPreview()
  → Map::undo()                         (applique localement)
  → Game.broadcastLastBatch(map)        (game_loader.cpp:221)
  → EditorOpBus.submitFromDelta(applyBefore=true)  → n'envoie que `before`
  → tous les peers appliquent l'inversion (applyRemoteDelta, SANS pushDelta)
```

---

## ✅ Bons points

1. **Le système A est solide et bien conçu.** Capture `before`/`after` complète par
   tuile (`game_loader.cpp:273-274`), `applyDelta` symétrique et **idempotent** : les
   gardes `if (tileById(...)) break;` (`map.cpp:335,348`) gèrent proprement le cas où
   un peer a déjà appliqué la mutation. Exactement ce qu'il faut en collaboratif.

2. **Sémantique redo correcte.** `pushDelta` vide le redoStack (`map.cpp:203`) : une
   nouvelle édition après un undo invalide bien le redo, pas de branche fantôme.

3. **Transactions par `groupId`.** `beginTransaction` / `commitTransaction`
   (`game_loader.cpp:356-376`) regroupent N deltas sous un même `groupId`, et
   `Map::undo` dépile tout le groupe d'un coup (`map.cpp:387-391`). Un undo = une
   action utilisateur logique, même si elle a touché 10 tuiles.

4. **Move / Resize / SetParam sont en réalité annulables** via `TileModified`
   (contrairement à ce que laisse penser le CLAUDE.md, qui parle du gap du système B).
   Le `before` vient de `tile->lastKnownJson()`, et `commitCurrentState()` met à jour
   la référence après coup. Le mécanisme de pré-image existe bel et bien — au niveau A.

5. **Collab : l'undo se propage** (`broadcastLastBatch`) et n'envoie que le côté
   nécessaire (`applyBefore` → `before` seul → économie de bande passante,
   `editor_op_bus.cpp:308-326`).

6. **Garde anti-boucle propre.** `m_isApplyingRemote` + compteur de profondeur
   `m_applyDepth` (`editor_op_bus.cpp:98-116`) empêche la ré-émission réseau des
   mutations issues d'un replay. `Game::updateMap` bail aussi tôt
   (`game_loader.cpp:265`).

---

## ❌ Mauvais points / dette

1. **Pile B = code mort + duplication.** `EditorOpBus::{undo,redo,clearUndo,
   submitOpWithUndo}`, `UndoEntry`, `m_undoStack/m_redoStack`, `undoDepth/redoDepth` :
   tout un système maintenu et jamais déclenché au clavier. Deux modèles d'undo
   concurrents pour le même éditeur = source de confusion durable. Le CLAUDE.md
   documente d'ailleurs le « gap » du système B comme si c'était la limite réelle,
   alors que A couvre déjà ces cas.

2. **L'undo des liens (connexions) est cassé.** Link/Unlink passent par
   `submitOpWithUndo` (système B, non branché) et **ne poussent pas de `EditDelta`**
   dans le système A. Conséquence : **Ctrl+Z n'annule pas une création/suppression de
   lien.** C'est le seul cas où le contenu de la pile B aurait servi — et il est
   inaccessible.

3. **Undo non borné.** Aucune limite de taille sur `m_undoStack` (Map). Chaque
   `EditDelta` embarque le JSON complet `before` + `after` de la tuile. Sur une grosse
   map éditée longtemps, la pile grossit sans fin en mémoire (pas de `MAX_UNDO`, pas de
   drop du plus ancien).

4. **Undo global en collab = pas d'undo « par utilisateur ».** Comme l'undo réel vit
   dans `Map` (état partagé répliqué) et non par client, un Ctrl+Z annule la *dernière
   action de la map*, qui peut être celle d'un autre joueur. Les peers reçoivent
   l'`ApplyState` mais `applyRemoteDelta` ne `pushDelta` pas (`game_loader.cpp:418`)
   → **leur redo ne connaît pas votre undo**, et leurs piles divergent. Piège classique
   du undo collaboratif (il faudrait un undo per-user façon OT/CRDT). Acceptable en v1,
   mais à documenter comme tel.

5. **Pas de persistance.** Les piles sont vidées au quit (`main.qml:156` + `clearUndo`).
   Attendu, mais combiné au point 3, l'historique est purement volatile.

6. **Incohérence de doc.** Le CLAUDE.md décrit le gap Move/Resize/Set* et « pas d'undo
   profils » comme la réalité fonctionnelle, alors que ces affirmations ne valent que
   pour le système B inactif. Un lecteur croit l'undo plus limité qu'il ne l'est (ou,
   à l'inverse, croit que B est utilisé).

---

## 🔧 Pistes d'amélioration (priorisées)

1. **Trancher entre A et B.** Recommandation : **supprimer le système B**
   (`EditorOpBus::undo/redo/submitOpWithUndo/UndoEntry/clearUndo`) et router Link/Unlink
   à travers le système A — c.-à-d. faire passer un changement de connexion par un
   `TileModified` delta (les liens sont déjà dans le JSON de la tuile via `rewireLinks`).
   Corrige le point ❌2 **et** élimine le point ❌1 d'un coup. Effort modéré, fort gain
   de clarté.

2. **Borner la pile** (`MAX_UNDO`, ex. 100-200) : drop du plus ancien dans `pushDelta`.
   Quelques lignes, supprime un risque mémoire.

3. **Aligner la doc** (CLAUDE.md + mémoire `multiplayer_editor_plan.md`) sur la réalité :
   « l'undo réel est `Map`/EditDelta, branché sur Ctrl+Z ; il couvre move/resize/set via
   `TileModified` ; `EditorOpBus.undo/redo` est dormant ».

4. **(Plus tard) Undo per-user en collab** : si le besoin se confirme, indexer les
   deltas par `_by` et ne dépiler que les siens. Gros chantier (cohérence OT), à ne
   lancer que si les utilisateurs se gênent réellement.

---

## Fichiers clés

| Chemin | Rôle |
|--------|------|
| `cpp/game/map/map.cpp:200-437` | Système A : `pushDelta`, `undo`, `redo`, `applyDelta` |
| `cpp/game/map/map.h:118-119` | `QStack<EditDelta> m_undoStack / m_redoStack` |
| `cpp/game/game_loader.cpp:214-237` | `askPreview` / `askNext` + `broadcastLastBatch` |
| `cpp/game/game_loader.cpp:252-376` | `updateMap`, transactions (`beginTransaction`/`commitTransaction`) |
| `qml/editor/EditorController.qml:78-92` | Interception clavier Ctrl+Z / Ctrl+Y |
| `cpp/editor/ops/editor_op_bus.cpp:120-176` | Système B (dormant) : `submitOpWithUndo`, `undo`, `redo`, `clearUndo` |
| `cpp/editor/ops/editor_op_bus.cpp:288-362` | `submitFromDelta` / `flushGroup` (broadcast Pattern B) |
| `qml/.../ConnectionsConfigurationSection.qml:238,290` | Seuls appelants de `submitOpWithUndo` (Link/Unlink) |
| `qml/main.qml:156` | `clearUndo` au quit |
