# Caisses attrapables & plaques de pression — état d'implémentation

Feature : **caisses** posables dans l'éditeur (nouveau
`TileType::PhysicalObjectTile`, ré-intégration de la brique
`PhysicalObjectParameter` conservée après le retrait de l'ancienne feature
caisses) + **saisie** en jeu (touche E) + **zones "plaque de pression"**
(pousser une caisse dans la zone active les éléments liés : porte ouverte,
récompense via les modules de gameplay).

Décalqué sur les features PNJ/ennemis, cf. `.claude/skills/editor-feature/SKILL.md`
et `ENEMY_COMBAT_PLAN.md` (le canal réseau combat de PhysicsSession est réutilisé).

## État d'implémentation (2026-07-03) — implémenté, build vert, vérifié

### Backend C++
- `ItemSnapable` : `PhysicalObjectTile` (=5, dernière valeur — borne du ctor
  JSON étendue), Q_PROPERTY `physicalObjectParameter`, parse/sérialisation
  gated/applyJson/operator==/dtor, `qmlRegisterType<PhysicalObjectParameter>`.
- `PhysicalObjectParameter` : + `grabbable` (bool, défaut true) sérialisé.
- `ItemSnapableFactory::createPhysicalObject()`.
- `ZoneParameter` : + `triggerMode` (0=None, 1=PressurePlate), `triggerOnce`
  (latch), `rewardCurrency`, `rewardItemName`, `rewardItemQuantity` —
  sérialisés (champs additifs, anciens JSON OK), copiés dans le copy-ctor.
- Op collab : `SetPhysicalObjectParameter = 19` + helper
  `makeSetPhysicalObjectParameterOp` + case remote-apply dans `Editor.qml`.
  Le trigger de zone passe par l'op `SetZoneParameter` existante (le
  panneau zone pousse le set complet ; `applyPhysicSettings` a des gardes
  `undefined` pour les nouveaux champs).

### UI éditeur
- `SnapablePhysicalObject.qml` (vignette 📦 + badge ⚖masse/✋) + qmldir +
  `base_comp.qrc`.
- `EditorLogic` : `cratePoseArmed`/`cratePoseConfig`/`armCratePose()`,
  désarmement croisé avec asset/case/PNJ/ennemi.
- `TileLogic.placeSelectedAsset` (branche caisse EN TÊTE) +
  `createItemSnapableTile` → `snapablePhysicalObjectComponent`.
- Module bas `moduleManager/crateSelectionPanel/` (`CratePanel` +
  `Crate_Content`, id catalogue `"crate"`, icône 🗃️). Coefficients saisis
  en **centièmes** (MeowSpinBox entier) : 100 → 1.0.
- Config sélection `configPanel/crateConfigPanel/`
  (`CrateConfigurationPanelSection`), branchée dans `BottomSidePanel(_Content)`
  + `updateSidePanel`. Édition → op `SetPhysicalObjectParameter` +
  `TileModified` débouncé 200 ms.
- Zone : `ZCP_TriggerSection` (switch plaque de pression + once + récompense
  💰/objet/qté) intégrée à `ZoneConfigurationPanelSection`
  (`getCurrentPhysicSettings` étendu, `SnapableElement.applyPhysicSettings`
  applique les nouveaux champs avec gardes undefined).

### Runtime (world3d)
- `CrateSpawner.qml` — par PhysicalObjectTile : body **Dynamic**
  `crate:<uuid>` (rayon = cercle inscrit de la tile × 0.9, mass/bounce/
  friction/damping du paramètre, ré-upsert à chaud) + cube 3D (`#Cube`
  dimensionné sur la tile via `_gridBasis`) positionné par `PhysicsActor`.
  Bodies possédés par l'autorité (pattern EnemySpawner).
- `GrabController.qml` — touche **E** (toggle) : attrape la caisse
  `grabbable` la plus proche (≤ 1.6 cellule), la relâche, ou lâche
  automatiquement au-delà de 3 cellules. Maintien par **ressort amorti**
  (`applyImpulse` ~30 Hz, J = m·Δv, norme bornée) vers un point à 0.9
  cellule du joueur — la caisse reste un body Dynamic (collisions
  respectées, permet de la pousser dans une plaque). Réseau : client →
  `{type:"grab"}` sur le canal combat ; autorité broadcast
  `{type:"grabState", actorId, crate}`. `lastHolderOf(uuid)` = attribution
  des récompenses.
- `TriggerController.qml` — le moteur émet `actorEnteredZone/ExitedZone`
  pour TOUT body (caisses incluses) : l'autorité suit les caisses par zone
  trigger. Zone active ⇔ ≥1 caisse dedans (latch si `triggerOnce`).
  - cibles liées (`next`) : zone d'exclusion → `removeZone` (porte
    physique ouverte), re-upsert via `EditorPhysicsBridge._upsertZoneNow`
    à la fermeture ; toute cible → tile 2D estompée (opacity 0.35, runtime
    only).
  - récompense one-shot par session (`rewardCurrency`/`rewardItemName`)
    créditée au dernier porteur de la caisse via
    `CombatController._applyLoot` (CurrencyModule/InventoryModule —
    tout l'état gameplay dans les modules).
  - réseau : broadcast `{type:"zoneTrigger", uuid, active}` + `loot` ;
    clients appliquent portes/visuel/miroirs.
  - arrêt du moteur → toutes les portes refermées, états purgés.
- `InputController` : entrée keymap `grab` (défaut E) + signal
  `grabRequested`. Branché dans `Editor.qml` → `grabController.toggleGrab()`.

### Automation
- `placeCrate(gx, gy, {mass, bounceFactor, frictionStrength, linearDamping,
  grabbable})` et `setZoneTrigger(uuid, {triggerMode, triggerOnce,
  rewardCurrency, rewardItemName, rewardItemQuantity})` dans
  `editorAutomationHooks` (setZoneTrigger broadcast le set complet — cf.
  note applyPhysicSettings).

### Vérifié en runtime (automation WS)
- placeCrate (mass 2, grabbable) + placeZone non-exclusion + setZoneTrigger
  (reward 50 + "Clé") → JSON de map correct (physicalObjectParameter +
  champs trigger), cube 3D rendu, screenshot OK.

## Écarts assumés / gaps connus (v1)
- Lien zone→cible via l'outil de connexion générique (pas de picker dédié
  dans la section Déclencheur).
- La récompense est one-shot **par session de jeu** (réarmée quand la
  physique redémarre), pas persistée.
- Le feedback 2D "porte ouverte" (opacity) n'est pas garanti avec le
  ZonesOverlayPainter global (il peut ignorer l'opacity de la tile) — la
  porte physique s'ouvre bien dans le moteur.
- Corps de caisse = cercle inscrit (pas de collision box) — cohérent avec
  le moteur (cercle-cercle / cercle-polygone uniquement).
- Pas d'indicateur "E pour attraper" à l'écran ; pas d'anim de saisie.
- Seules les caisses déclenchent les plaques (pas le joueur) — choix v1,
  filtre `crate:` dans TriggerController.
