# Ennemis & combat — plan et état d'implémentation

Feature : éléments **ennemis** posables dans l'éditeur (nouveau
`TileType::EnemyTile`) + **système de combat** en jeu (IA
aggro/poursuite/attaque, PV via le `HealthModule` des modules de gameplay,
attaque du joueur à la touche Espace, barres de vie).

Décalqué sur la feature PNJ (commit `c3f252f7`, cf.
`NPC_DIALOGUE_PLAN.md`) en suivant `.claude/skills/editor-feature/SKILL.md`.

## État d'implémentation (2026-07-03) — implémenté, build vert, round-trip validé

### Backend C++
- `cpp/game/item_snapable/enemyparameter.{h,cpp}` — `EnemyParameter` :
  `enemyName`, `modelName`, `maxHp`, `attackDamage`, `attackRange` (cellules),
  `attackCooldownMs`, `aggroRange`, `moveSpeed`, `respawnEnabled`,
  `respawnDelayMs`. Schéma versionné `enemyVersion` (courant : 1), toJSON via
  `QJsonDocument` (texte libre), `applyJson` Q_INVOKABLE, `operator==`.
- `ItemSnapable` : `EnemyTile` (=4, dernière valeur de l'enum — borne du ctor
  JSON étendue), `Q_PROPERTY enemyParameter`, parse ctor JSON, sérialisation
  gated `tileType == EnemyTile`, applyJson, case `operator==`, registerQml.
- `ItemSnapableFactory::createEnemy()`.
- `Map::updateTileCounts` : EnemyTile tombe dans `default:` (non compté,
  comme NPCTile) — assumé.

### Op collab
- `SetEnemyParameter = 18` (`editor_op_type.h`),
  `EditorOpBus::makeSetEnemyParameterOp(uuid, fields)`, case remote-apply
  dans `Editor.qml`. Création/suppression/déplacement via les ops génériques.

### UI éditeur
- `qml/meowComponent/snapable/SnapableEnemy.qml` (vignette 👹 + badge
  ❤maxHp ⚔dégâts) + qmldir + `base_comp.qrc`.
- `EditorLogic` : `enemyPoseArmed`/`enemyPoseConfig`/`armEnemyPose()`,
  désarmement croisé avec asset/case/PNJ.
- `TileLogic.placeSelectedAsset` (branche ennemi en tête) +
  `createItemSnapableTile` → `snapableEnemyComponent`
  (`EditorDynamicComponent`).
- Module bas `moduleManager/enemySelectionPanel/` (`EnemyPanel` +
  `Enemy_Content`, id catalogue `"enemy"`, icône 👹), entrée
  `_bottomModuleActive`. Les portées/vitesse sont saisies en **dixièmes de
  cellule** (MeowSpinBox entier).
- Config sélection `configPanel/enemyConfigPanel/`
  (`EnemyConfigurationPanelSection` + `ECP_IdentitySection` +
  `ECP_CombatSection`), branché dans `BottomSidePanel(_Content)` +
  `updateSidePanel`. Édition → op `SetEnemyParameter` + `TileModified`
  débouncé 200 ms.

### Runtime (world3d)
- `CombatController.qml` — non visuel. Tick IA 10 Hz : par ennemi vivant,
  `bodyState` ennemi vs joueur (coords grille) → `dist ≤ attackRange` : stop
  + dégâts au joueur (cooldown par ennemi) ; `≤ aggroRange` : poursuite
  (`pushInput` normalisé) ; sinon immobile. PV joueur + ennemis dans le
  `HealthModule` (ids `player` / `enemy:<uuid>`), module activé
  automatiquement au démarrage du combat. Mort ennemie → flag `dead` +
  `stateRevision++` (+ respawn différé si `respawnEnabled`) ; mort du joueur
  → respawn auto après `playerRespawnDelayMs` (3 s).
  `playerAttack()` : ennemi vivant le plus proche dans `playerAttackRange`
  (1.5 cellule, dégâts 10, cooldown 400 ms — fixes en v1).
- `EnemySpawner.qml` — par EnemyTile : body **Kinematic** `enemy:<uuid>`
  (`maxSpeed = moveSpeed`, re-upsert à chaud sur `moveSpeedChanged`) +
  `Node`/`SkinnedModel` positionné par un `PhysicsActor` (même pattern que le
  joueur). Body retiré à la mort / recréé au respawn (observe
  `stateRevision`).
- `EnemyHealthOverlay.qml` — barres de vie en coords workArea, position
  suivie sur `bodyState` (Timer 10 Hz), couleur verte→orange→rouge.
- `PlayerHealthHud.qml` — HUD fixe (❤ hp/maxHp), visible quand
  `combat.active`.
- `InputController` : entrée keymap `attack` (défaut Espace) + signal
  `attackRequested` (événement ponctuel, ne passe PAS par le vecteur
  pushInput). Branché dans `Editor.qml` → `combatController.playerAttack()`.

### Automation
- Hook `placeEnemy(modelName, gx, gy, options)` dans
  `editorAutomationHooks` (chemin UI complet, compatible collab/undo).

### Vérifié en runtime (automation WS, port 7700)
- Pose via hook avec nom piégé (`"` + `\n`) → JSON de map correct
  (échappement QJsonDocument), `_tileCount` cohérent.
- Round-trip AUTOSAVE : pose → save → quit → relance → tiles rechargées,
  rendu 2D + barre de vie + HUD joueur visibles (screenshots).

## Écarts assumés / gaps connus (v1)
- **Pas de synchro réseau du combat** : la résolution tourne localement (sur
  l'hôte si PhysicsSession active — les positions des bodies ennemis sont
  snapshotées par PhysicsSession, mais PV/morts/dégâts ne transitent pas ;
  il faudra un canal de sync gameplay dédié).
- Stats d'attaque du **joueur** fixes (pas encore portées par
  `PlayerProfile`).
- Pas d'undo sur l'édition des champs ennemi (`submitOp`-like, comme les
  profils joueurs) ; Create/Delete passent par le circuit standard.
- Pas d'animation d'attaque/mort (le node disparaît à la mort) ; pas de
  son ; pas de loot (brancher `InventoryModule`/`CurrencyModule` plus tard).
- `TemplatePreviewCursor` ne prévisualise pas spécifiquement les ennemis
  (fallback générique, parité avec les PNJ).
