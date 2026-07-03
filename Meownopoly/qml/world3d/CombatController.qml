/*
 * CombatController — logique de combat joueur ↔ ennemis (EnemyTile).
 *
 * Non visuel. Tout l'état gameplay vit dans les modules de gameplay
 * (GameplayModuleManager) — jamais dans des variables parallèles :
 *  - PV joueurs + ennemis : HealthModule (ids : actorId / "enemy:<uuid>")
 *  - monnaie de loot      : CurrencyModule
 *  - objets de loot       : InventoryModule
 *
 * Résolution host-authoritative (Phase réseau) :
 *  - autorité = pas de PhysicsSession active (monoposte) OU hôte de la
 *    session. Seule l'autorité fait tourner l'IA (tick 10 Hz), applique les
 *    dégâts, tue, respawn et attribue le loot.
 *  - client : ses attaques partent en AttackRequest (PhysicsSession) vers
 *    l'hôte ; il applique les CombatEvent reçus (hp / enemyDeath /
 *    enemyRespawn / enemyAttack / loot) sur ses miroirs de modules locaux.
 *  - l'IA de l'hôte cible le joueur vivant le plus proche parmi son propre
 *    actor + les actors revendiqués par les clients (remoteClaimedActors).
 *
 * Stats d'attaque du joueur : lues dans `playerProfile` (PlayerProfile de la
 * map, cf. onglet Joueurs) quand il est fourni, sinon défauts. Si le
 * StatsModule est actif, le profil est poussé en STATS DE BASE
 * (`damage`/`maxHealth`) et le combat lit les stats EFFECTIVES (base +
 * modificateurs d'équipement/effets) — cf. philosophie de StatsModule.
 * La stat `maxHealth` est répercutée sur HealthModule par le câblage du
 * GameplayModuleManager (statChanged → setMaxHp).
 *
 * IA par ennemi vivant : dist ≤ attackRange → stop + attaque (cooldown) ;
 * ≤ aggroRange → poursuite (pushInput) ; sinon immobile. Mort d'un ennemi →
 * flag `dead` + stateRevision++ (body retiré par EnemySpawner) + loot ;
 * respawn optionnel piloté par EnemyParameter. Les joueurs (local et
 * distants) respawnent toujours après playerRespawnDelayMs.
 */
import QtQuick
import ItemSnapable
import GameplayModuleManager 1.0
import Pattounx 1.0

Item {
    id: root
    visible: false

    required property var physicsWorld
    /// GridManager de l'éditeur (conversion pixels tile → coords grille).
    property var gridManager: null
    /// snapableTilesList de l'éditeur.
    property var tilesList: []
    /// Incrémenté par l'hôte sur snapableTilesListUpdated.
    property int tilesRevision: 0

    property string playerActorId: "player"
    readonly property bool active: physicsWorld ? physicsWorld.running : false

    // ── Réseau (PhysicsSession) ───────────────────────────────────────────
    readonly property bool networked: PhysicsSession.active
    /// True si ce pair résout le combat (monoposte ou hôte de session).
    readonly property bool isAuthority: !PhysicsSession.active || PhysicsSession.isHost
    /// Actor local effectif : en client réseau, l'actor revendiqué.
    readonly property string localActorId:
        (networked && !PhysicsSession.isHost && PhysicsSession.claimedActorId !== "")
            ? PhysicsSession.claimedActorId : playerActorId

    // ── Stats d'attaque du joueur (StatsModule > PlayerProfile > défauts) ──
    /// PlayerProfile de la map appliqué au joueur local (null = défauts).
    property var playerProfile: null
    readonly property real playerAttackRange:
        playerProfile ? playerProfile.attackRange : 1.5
    /// Dégâts effectifs : stat `damage` (base profil + modificateurs) quand
    /// le StatsModule est actif, sinon le profil brut.
    readonly property int playerAttackDamage: {
        statsRevision
        if (statsDriven)
            return Math.max(0, Math.round(_stats.effectiveStat(localActorId, "damage")))
        return playerProfile ? playerProfile.attackDamage : 10
    }
    readonly property int playerAttackCooldownMs:
        playerProfile ? playerProfile.attackCooldownMs : 400
    property int playerRespawnDelayMs: 3000

    readonly property var _health: GameplayModuleManager.healthModule
    readonly property var _currency: GameplayModuleManager.currencyModule
    readonly property var _inventory: GameplayModuleManager.inventoryModule
    readonly property var _stats: GameplayModuleManager.statsModule

    /// True si le StatsModule pilote les stats de combat du joueur.
    readonly property bool statsDriven: _stats ? _stats.enabled : false
    /// Incrémenté sur statChanged — les bindings de stats effectives s'y
    /// suspendent (effectiveStat est un appel de fonction, pas observable).
    property int statsRevision: 0

    // État interne par uuid d'ennemi :
    // { dead, lastAttackMs, respawnAtMs, registered }
    property var _states: ({})
    // Respawns joueurs planifiés par l'autorité : { actorId: atMs }.
    property var _pendingPlayerRespawns: ({})
    // Incrémenté à chaque changement d'état observable (dégâts, mort,
    // respawn, loot) — les overlays et EnemySpawner s'y suspendent.
    property int stateRevision: 0

    property real _playerLastAttackMs: 0
    property bool _playerDead: false

    signal enemyDied(string uuid)
    signal playerHit(string uuid, int damage)
    signal playerAttacked()
    signal lootGranted(string actorId, int currency, string itemName, int itemQuantity)

    readonly property var _enemyTiles: {
        tilesRevision
        const out = []
        const list = root.tilesList
        if (!list) return out
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            const sp = t ? t.snapableParameters : null
            if (!sp || sp.tileType !== ItemSnapable.EnemyTile) continue
            out.push(t)
        }
        return out
    }

    function bodyIdFor(uuid) { return "enemy:" + uuid }

    function isDead(uuid) {
        const s = _states[String(uuid)]
        return !!(s && s.dead)
    }

    function hpOf(uuid) {
        if (!_health) return 0
        return _health.hp(bodyIdFor(String(uuid)))
    }

    function maxHpOf(uuid) {
        if (!_health) return 1
        return _health.maxHp(bodyIdFor(String(uuid)))
    }

    function _tileByUuid(uuid) {
        const tiles = _enemyTiles
        for (let i = 0; i < tiles.length; i++) {
            if (String(tiles[i].snapableParameters.uniqueId) === uuid)
                return tiles[i]
        }
        return null
    }

    /// Centre de la tile en coords grille (position de spawn/respawn).
    function spawnPosFor(tile) {
        const gs = gridManager ? gridManager.gridSize : 0
        if (!tile || gs <= 0) return Qt.vector2d(0, 0)
        return Qt.vector2d((tile.x + tile.width / 2) / gs,
                           (tile.y + tile.height / 2) / gs)
    }

    function _ensureState(tile) {
        const uuid = String(tile.snapableParameters.uniqueId)
        let s = _states[uuid]
        if (!s) {
            s = { dead: false, lastAttackMs: 0, respawnAtMs: 0, registered: false }
            _states[uuid] = s
        }
        if (!s.registered && _health && _health.enabled) {
            _health.registerPlayer(bodyIdFor(uuid),
                                   tile.snapableParameters.enemyParameter.maxHp)
            s.registered = true
        }
        return s
    }

    /// Actors joueurs ciblables par l'IA (autorité uniquement) : le joueur
    /// local + les actors revendiqués par les clients distants.
    function _targetActorIds() {
        const out = [localActorId]
        if (networked && PhysicsSession.isHost) {
            const claims = PhysicsSession.remoteClaimedActors()
            for (let i = 0; i < claims.length; i++) {
                if (claims[i] !== "" && out.indexOf(claims[i]) < 0)
                    out.push(claims[i])
            }
        }
        return out
    }

    /// PV max effectifs du joueur : stat `maxHealth` quand le StatsModule
    /// est actif, sinon le profil (0 = defaultMaxHp du HealthModule).
    function _effectiveMaxHp() {
        if (statsDriven)
            return Math.max(1, Math.round(_stats.effectiveStat(localActorId, "maxHealth")))
        return playerProfile ? playerProfile.maxHp : 0
    }

    /// Pousse le profil en stats de base (l'équipement/les effets empilent
    /// leurs modificateurs par-dessus).
    function _pushProfileBaseStats() {
        if (!statsDriven || !playerProfile) return
        _stats.setBaseStat(localActorId, "damage", playerProfile.attackDamage)
        _stats.setBaseStat(localActorId, "maxHealth", playerProfile.maxHp)
    }

    function _registerLocalPlayer() {
        if (!_health) return
        _health.enabled = true
        _pushProfileBaseStats()
        _health.registerPlayer(localActorId, _effectiveMaxHp())
        _playerDead = _health.isDead(localActorId)
    }

    // Activation du combat : module de vie ON + joueur enregistré.
    // Arrêt : reset complet de l'état interne — sinon les ennemis restent
    // morts au test suivant, les respawns pendants firent instantanément à
    // la reprise et les flags `registered` sont périmés (TriggerController
    // fait ce nettoyage correctement — on s'aligne).
    onActiveChanged: {
        if (active) {
            _registerLocalPlayer()
        } else {
            _states = ({})
            _pendingPlayerRespawns = ({})
            _playerDead = false
            _playerLastAttackMs = 0
            stateRevision++
        }
    }
    // Profil (re)créé ou changé pendant le test : re-register (full heal —
    // acceptable en mode test éditeur, le maxHp doit suivre le profil).
    onPlayerProfileChanged: if (active) _registerLocalPlayer()

    // Mort/résurrection : suivi local + planification de respawn (autorité).
    Connections {
        target: root._health
        function onPlayerDied(playerId) {
            if (playerId === root.localActorId) root._playerDead = true
            // L'autorité planifie le respawn de tout joueur (local ou
            // distant) — jamais des ennemis (respawn géré par _states).
            if (root.isAuthority && playerId.indexOf("enemy:") !== 0) {
                root._pendingPlayerRespawns[playerId] =
                        Date.now() + root.playerRespawnDelayMs
            }
            root.stateRevision++
        }
        function onPlayerRevived(playerId) {
            if (playerId === root.localActorId) root._playerDead = false
            root.stateRevision++
        }
        function onHealthChanged(playerId, hp, maxHp) {
            // Rafraîchit les barres de vie (ennemis + HUD joueur) et
            // propage l'état aux clients (l'autorité est la vérité).
            root.stateRevision++
            if (root.isAuthority && root.networked) {
                PhysicsSession.broadcastCombatEvent({
                    type: "hp", id: playerId, hp: hp, maxHp: maxHp
                })
            }
        }
    }

    // Stats : re-suspend les bindings de stats effectives (damage, maxHealth).
    // La répercussion maxHealth → HealthModule.setMaxHp est faite par le
    // GameplayModuleManager, pas ici.
    Connections {
        target: root._stats
        function onStatChanged(playerId, statKey, baseValue, effectiveValue) {
            root.statsRevision++
        }
        function onEnabledChanged() {
            // Activation/désactivation du module pendant le test : resynchro
            // complète (base stats + maxHp, full heal — mode test éditeur).
            if (root.active) root._registerLocalPlayer()
            root.statsRevision++
        }
    }

    // Le solde/l'inventaire changent → rafraîchit les HUD suspendus à
    // stateRevision (l'état lui-même reste dans les modules).
    Connections {
        target: root._currency
        function onBalanceChanged(playerId, balance) { root.stateRevision++ }
    }
    Connections {
        target: root._inventory
        function onInventoryChanged(playerId) { root.stateRevision++ }
    }

    // ── Réseau : requêtes (hôte) et événements (client) ───────────────────
    Connections {
        target: PhysicsSession
        function onCombatRequestReceived(senderId, req) {
            if (!root.isAuthority || !root.active) return
            if (req.type === "attack") {
                // Sanity clamp : on fait confiance au client (coop) mais on
                // borne aux plages du PlayerProfile.
                const dmg = Math.min(999, Math.max(0, Number(req.damage) || 10))
                const rng = Math.min(10, Math.max(0.1, Number(req.range) || 1.5))
                const attacker = String(req.actorId || "")
                if (attacker !== "") root._resolveAttack(attacker, dmg, rng)
            }
        }
        function onCombatEventReceived(ev) {
            if (root.isAuthority) return
            root._applyCombatEvent(ev)
        }
    }

    /// Client : applique un CombatEvent de l'hôte sur les miroirs locaux.
    function _applyCombatEvent(ev) {
        if (!ev || !_health) return
        switch (ev.type) {
        case "hp": {
            _health.enabled = true
            const id = String(ev.id)
            // registerPlayer si maxHp inconnu/différent (met full), puis setHp
            // — setHp émet playerDied/playerRevived aux transitions.
            if (_health.maxHp(id) !== ev.maxHp) _health.registerPlayer(id, ev.maxHp)
            _health.setHp(id, ev.hp)
            break
        }
        case "enemyDeath": {
            const uuid = String(ev.uuid)
            let s = _states[uuid]
            if (!s) { s = { dead: false, lastAttackMs: 0, respawnAtMs: 0, registered: true }; _states[uuid] = s }
            s.dead = true
            stateRevision++
            enemyDied(uuid)
            break
        }
        case "enemyRespawn": {
            const uuid = String(ev.uuid)
            const s = _states[uuid]
            if (s) { s.dead = false; s.respawnAtMs = 0 }
            stateRevision++
            break
        }
        case "enemyAttack":
            playerHit(String(ev.uuid), Number(ev.damage) || 0)
            break
        case "loot":
            _applyLoot(String(ev.to), Number(ev.currency) || 0,
                       String(ev.itemName || ""), Number(ev.itemQuantity) || 1)
            break
        }
    }

    /// Attaque du joueur local (touche Espace). Client → requête à l'hôte ;
    /// autorité → résolution directe.
    function playerAttack() {
        if (!active || !_health || _playerDead) return
        const now = Date.now()
        if (now - _playerLastAttackMs < playerAttackCooldownMs) return
        _playerLastAttackMs = now
        playerAttacked()

        if (!isAuthority) {
            PhysicsSession.sendCombatRequest({
                type: "attack",
                actorId: localActorId,
                damage: playerAttackDamage,
                range: playerAttackRange
            })
            return
        }
        _resolveAttack(localActorId, playerAttackDamage, playerAttackRange)
    }

    /// Autorité : résout une attaque de `attackerActorId` — touche l'ennemi
    /// vivant le plus proche dans `range`.
    function _resolveAttack(attackerActorId, damage, range) {
        if (!physicsWorld || !_health) return
        const ps = physicsWorld.bodyState(attackerActorId)
        if (!ps.id) return

        let best = null
        let bestDist = range
        const tiles = _enemyTiles
        for (let i = 0; i < tiles.length; i++) {
            const tile = tiles[i]
            const uuid = String(tile.snapableParameters.uniqueId)
            if (isDead(uuid)) continue
            const es = physicsWorld.bodyState(bodyIdFor(uuid))
            if (!es.id) continue
            const dx = es.position.x - ps.position.x
            const dy = es.position.y - ps.position.y
            const dist = Math.sqrt(dx * dx + dy * dy)
            if (dist <= bestDist) {
                bestDist = dist
                best = tile
            }
        }
        if (!best) return

        const uuid = String(best.snapableParameters.uniqueId)
        const s = _ensureState(best)
        _health.damage(bodyIdFor(uuid), damage)
        if (_health.isDead(bodyIdFor(uuid)))
            _killEnemy(best, s, uuid, attackerActorId)
    }

    /// Autorité : mort d'un ennemi — flag dead, respawn éventuel, broadcast,
    /// loot au tueur via les modules de gameplay.
    function _killEnemy(tile, s, uuid, killerActorId) {
        s.dead = true
        const ep = tile.snapableParameters.enemyParameter
        if (ep.respawnEnabled)
            s.respawnAtMs = Date.now() + ep.respawnDelayMs
        stateRevision++
        enemyDied(uuid)
        if (networked) {
            PhysicsSession.broadcastCombatEvent({ type: "enemyDeath", uuid: uuid })
        }

        // Loot : monnaie (CurrencyModule) + objet (InventoryModule).
        const currency = ep.lootCurrency
        const itemName = ep.lootItemName
        const itemQty = ep.lootItemQuantity
        if (currency > 0 || itemName !== "") {
            _applyLoot(killerActorId, currency, itemName, itemQty)
            if (networked) {
                PhysicsSession.broadcastCombatEvent({
                    type: "loot", to: killerActorId, currency: currency,
                    itemName: itemName, itemQuantity: itemQty
                })
            }
        }
    }

    /// Applique le loot dans les modules (autorité ET miroirs clients).
    function _applyLoot(actorId, currency, itemName, itemQuantity) {
        if (actorId === "") return
        if (currency > 0 && _currency) {
            _currency.enabled = true
            _currency.credit(actorId, currency)
        }
        if (itemName !== "" && _inventory) {
            _inventory.enabled = true
            _inventory.addItem(actorId, itemName, Math.max(1, itemQuantity))
        }
        stateRevision++
        lootGranted(actorId, currency, itemName, itemQuantity)
    }

    // ── Tick IA (autorité uniquement) ─────────────────────────────────────
    Timer {
        interval: 100
        repeat: true
        running: root.active && root.isAuthority
        onTriggered: root._aiTick()
    }

    function _aiTick() {
        if (!physicsWorld || !_health) return
        const now = Date.now()

        // Respawns joueurs planifiés (local + distants).
        const respawns = _pendingPlayerRespawns
        for (const pid in respawns) {
            if (now >= respawns[pid]) {
                delete respawns[pid]
                _health.revive(pid)
            }
        }

        // Positions des cibles joueurs vivantes.
        const targetIds = _targetActorIds()
        const targets = []
        for (let i = 0; i < targetIds.length; i++) {
            if (_health.isDead(targetIds[i])) continue
            const ts = physicsWorld.bodyState(targetIds[i])
            if (ts.id) targets.push(ts)
        }

        const tiles = _enemyTiles
        for (let i = 0; i < tiles.length; i++) {
            const tile = tiles[i]
            const sp = tile.snapableParameters
            const ep = sp.enemyParameter
            const uuid = String(sp.uniqueId)
            const s = _ensureState(tile)
            const bodyId = bodyIdFor(uuid)

            // Respawn différé : PV pleins + repositionnement au point de spawn.
            if (s.dead) {
                if (s.respawnAtMs > 0 && now >= s.respawnAtMs) {
                    s.dead = false
                    s.respawnAtMs = 0
                    _health.revive(bodyId)
                    stateRevision++
                    if (networked) {
                        PhysicsSession.broadcastCombatEvent({
                            type: "enemyRespawn", uuid: uuid
                        })
                    }
                    // Le body est recréé par EnemySpawner (observe stateRevision).
                }
                continue
            }

            const es = physicsWorld.bodyState(bodyId)
            if (!es.id) continue

            // Cible = joueur vivant le plus proche.
            let target = null
            let targetDist = Infinity
            for (let t = 0; t < targets.length; t++) {
                const dx = targets[t].position.x - es.position.x
                const dy = targets[t].position.y - es.position.y
                const d = Math.sqrt(dx * dx + dy * dy)
                if (d < targetDist) { targetDist = d; target = targets[t] }
            }
            if (!target) {
                physicsWorld.pushInput(bodyId, Qt.vector2d(0, 0))
                continue
            }

            const dx = target.position.x - es.position.x
            const dy = target.position.y - es.position.y

            if (targetDist <= ep.attackRange) {
                physicsWorld.pushInput(bodyId, Qt.vector2d(0, 0))
                if (now - s.lastAttackMs >= ep.attackCooldownMs) {
                    s.lastAttackMs = now
                    _health.damage(String(target.id), ep.attackDamage)
                    playerHit(uuid, ep.attackDamage)
                    if (networked) {
                        PhysicsSession.broadcastCombatEvent({
                            type: "enemyAttack", uuid: uuid,
                            target: String(target.id), damage: ep.attackDamage
                        })
                    }
                }
            } else if (targetDist <= ep.aggroRange && targetDist > 0.0001) {
                physicsWorld.pushInput(bodyId,
                                       Qt.vector2d(dx / targetDist, dy / targetDist))
            } else {
                physicsWorld.pushInput(bodyId, Qt.vector2d(0, 0))
            }
        }
    }
}
