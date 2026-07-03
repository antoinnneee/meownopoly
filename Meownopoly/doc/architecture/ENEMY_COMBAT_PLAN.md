# Ennemis & combat — plan et état d'implémentation

Feature : éléments **ennemis** posables dans l'éditeur (nouveau
`TileType::EnemyTile`) + **système de combat** en jeu (IA
aggro/poursuite/attaque, PV via le `HealthModule` des modules de gameplay,
attaque du joueur à la touche Espace, barres de vie).

Décalqué sur la feature PNJ (commit `c3f252f7`, cf.
`NPC_DIALOGUE_PLAN.md`) en suivant `.claude/skills/editor-feature/SKILL.md`.

## État d'implémentation (2026-07-03, v2) — implémenté, build vert, round-trip validé

### v2 — synchro réseau + stats profil + animations + loot (même jour)
- **Synchro réseau du combat (host-authoritative)** :
  - `PhysicsMessageType` : `AttackRequest = 0x44` (client→hôte),
    `CombatEvent = 0x45` (hôte→tous) — borne d'`isPhysicsPacket` étendue.
  - `PhysicsSession` : `sendCombatRequest(QVariantMap)` /
    `broadcastCombatEvent(QVariantMap)` Q_INVOKABLE, signaux
    `combatRequestReceived(senderId, payload)` / `combatEventReceived(payload)`,
    `remoteClaimedActors()` + signal `remoteClaimsChanged` (cibles IA).
  - `CombatController` : `isAuthority` = monoposte OU hôte. Seule l'autorité
    fait tourner l'IA/dégâts/morts/respawns/loot. Client : attaques en
    `AttackRequest {type:"attack", actorId, damage, range}` (stats du profil
    embarquées, clampées côté hôte) ; applique les `CombatEvent`
    (`hp`/`enemyDeath`/`enemyRespawn`/`enemyAttack`/`loot`) sur ses miroirs
    de modules. L'IA de l'hôte cible le joueur vivant **le plus proche**
    parmi son actor + les claims distants ; l'autorité planifie aussi le
    respawn des joueurs distants (`_pendingPlayerRespawns`).
  - `EnemySpawner` : bodies possédés par l'autorité uniquement (côté client
    ils arrivent par snapshot ; `_syncBody` no-op).
- **Stats de combat dans `PlayerProfile`** : `maxHp` (100), `attackDamage`
  (10), `attackRange` (1.5), `attackCooldownMs` (400) — sérialisés
  (champs additifs, pas de bump `playerConfigVersion`), édités dans la
  nouvelle section `PCP_CombatSection` (sliders, onglet Joueurs) via le
  circuit `UpdatePlayerProfile` existant. `CombatController.playerProfile`
  (branché sur le profil en test `PCP_TestController`) fournit les stats et
  le maxHp d'enregistrement du joueur.
- **Loot** : `EnemyParameter.lootCurrency` / `lootItemName` /
  `lootItemQuantity` (sérialisés, `enemyVersion` reste 1 — champs additifs).
  À la mort, l'autorité crédite le **tueur** via `CurrencyModule.credit` +
  `InventoryModule.addItem` (modules activés à la volée) et broadcast
  l'événement `loot` — tout l'état gameplay vit dans les modules, aucun
  état parallèle. UI : colonne « Loot » dans `Enemy_Content` (pose) +
  lignes loot dans `ECP_CombatSection` (config), hook `placeEnemy`
  étendu (`lootCurrency`/`lootItemName`/`lootItemQuantity`).
- **Animations procédurales** (présentation pure, jamais le moteur) :
  - mort d'un ennemi : écrasement `scale → (1.2, 0.05, 1.2)` 450 ms
    (le node reste visible pendant `deathAnim.running`) ;
  - respawn : pop-in `OutBack` 350 ms ;
  - attaque d'un ennemi (`playerHit`) : hop `PhysicsActor.jump(0.5, 250)` ;
  - attaque du joueur (`playerAttacked`) : `playerActor.jump(0.4, 200)`.
- **HUD** : `PlayerHealthHud` lit `combat.localActorId` (claim réseau) et
  affiche 💰 solde (si CurrencyModule actif) + 🎒 total d'objets (si
  InventoryModule actif) — lecture directe des modules via `stateRevision`.

### v3 — branchement StatsModule (damage / maxHealth / speed)
Post-merge des modules statistiques/équipement (`182bacbd`). Règle :
**profil = stats de base, équipement/effets = modificateurs** ; le combat lit
les stats EFFECTIVES quand le `StatsModule` est actif, sinon le profil brut
(comportement inchangé module OFF).
- `CombatController` : `statsDriven` (= `statsModule.enabled`) +
  `statsRevision` (les bindings se re-suspendent sur `statChanged`).
  `playerAttackDamage` lit `effectiveStat(localActorId, "damage")` ;
  `_registerLocalPlayer` pousse d'abord le profil en stats de base
  (`_pushProfileBaseStats` : `damage`, `maxHealth`) puis enregistre le joueur
  au `maxHealth` effectif. La répercussion `maxHealth → HealthModule.setMaxHp`
  est faite par le câblage du `GameplayModuleManager` (pas de soin gratuit :
  hp inchangé quand le max monte). Toggle du module en cours de test →
  resynchro complète (full heal, assumé en mode test).
- `Editor.qml` : stat `speed` **multiplicative** (base 1.0) —
  `_statSpeedFactor()` (borne basse 0.1) multiplie `maxSpeed` ET
  `acceleration` dans `_resyncMainPlayer` (réactivité de conduite conservée) ;
  re-upsert du body sur `statChanged("speed")` / `enabledChanged`.
- `attackRange`/`attackCooldownMs` restent profil-only (pas dans
  `knownStats()` v1).
- Hooks automation : `setStatsModuleEnabled(on)`,
  `addPlayerStatModifier(statKey, value)` (source `"automation"`),
  `getPlayerCombatStats()`.
- Vérifié en runtime : OFF → 10 dmg/100 PV/×1.0 ; ON + modificateurs
  (+15 dmg, +50 maxHealth, +0.5 speed) → 25 dmg / 150 PV max (hp 100
  conservé) / ×1.5 ; retour OFF → défauts restaurés.

### v1 — base (historique)

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

## Écarts assumés / gaps connus (v2)
- La synchro réseau du combat est **branchée mais non exercée en éditeur** :
  l'éditeur collab ne démarre pas de `PhysicsSession` aujourd'hui (le canal
  est utilisé par le harness CatwayTest). Quand une session physique
  démarrera dans l'éditeur, le combat suivra sans changement.
- Confiance au client sur ses stats d'attaque (transmises dans
  `AttackRequest`, clampées aux bornes du `PlayerProfile` côté hôte) —
  acceptable en coop.
- Pas d'undo sur l'édition des champs ennemi (`submitOp`-like, comme les
  profils joueurs) ; Create/Delete passent par le circuit standard.
- Pas de son ; animations procédurales simples (écrasement/pop/hop), pas
  d'animations squelettales.
- `TemplatePreviewCursor` ne prévisualise pas spécifiquement les ennemis
  (fallback générique, parité avec les PNJ).
- Le loot `itemName` est un texte libre (pas de catalogue d'objets).
