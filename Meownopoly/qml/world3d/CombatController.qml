/*
 * CombatController — logique de combat joueur ↔ ennemis (EnemyTile).
 *
 * Non visuel. Tick IA à 10 Hz :
 *  - chaque ennemi vivant lit sa position et celle du joueur via
 *    physicsWorld.bodyState (coords grille) ;
 *  - dist ≤ attackRange  → stop + attaque (cooldown par ennemi) ;
 *  - dist ≤ aggroRange   → poursuite (pushInput vers le joueur) ;
 *  - sinon               → immobile.
 *
 * Les PV (joueur + ennemis) vivent dans le HealthModule des modules de
 * gameplay (ids : playerActorId et "enemy:<uuid>") — le module est activé
 * automatiquement quand le combat démarre. La mort d'un ennemi le marque
 * `dead` (le body est retiré par EnemySpawner qui observe stateRevision) ;
 * respawn optionnel piloté par EnemyParameter.respawnEnabled/DelayMs.
 * Le joueur, lui, respawn toujours après playerRespawnDelayMs.
 *
 * v1 locale : la résolution tourne sur l'instance qui simule la physique
 * (l'hôte en session PhysicsSession) ; la synchro réseau des PV n'est pas
 * encore branchée (gap connu, cf. plan).
 */
import QtQuick
import ItemSnapable
import GameplayModuleManager 1.0

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

    // Stats d'attaque du joueur (v1 : fixes, pas encore portées par le profil).
    property real playerAttackRange: 1.5
    property int playerAttackDamage: 10
    property int playerAttackCooldownMs: 400
    property int playerRespawnDelayMs: 3000

    readonly property var _health: GameplayModuleManager.healthModule

    // État interne par uuid d'ennemi :
    // { dead, lastAttackMs, respawnAtMs, registered }
    property var _states: ({})
    // Incrémenté à chaque changement d'état observable (dégâts, mort,
    // respawn) — les overlays et EnemySpawner s'y suspendent.
    property int stateRevision: 0

    property real _playerLastAttackMs: 0
    property bool _playerDead: false

    signal enemyDied(string uuid)
    signal playerHit(string uuid, int damage)
    signal playerAttacked()

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

    // Activation du combat : module de vie ON + joueur enregistré.
    onActiveChanged: {
        if (active && _health) {
            _health.enabled = true
            _health.registerPlayer(playerActorId)
            _playerDead = _health.isDead(playerActorId)
        }
    }

    // Mort/résurrection du joueur : stop inputs + respawn différé.
    Connections {
        target: root._health
        function onPlayerDied(playerId) {
            if (playerId === root.playerActorId) {
                root._playerDead = true
                root.stateRevision++
                playerRespawnTimer.restart()
            }
        }
        function onPlayerRevived(playerId) {
            if (playerId === root.playerActorId) {
                root._playerDead = false
                root.stateRevision++
            }
        }
        function onHealthChanged(playerId, hp, maxHp) {
            // Rafraîchit les barres de vie (ennemis + HUD joueur).
            root.stateRevision++
        }
    }

    Timer {
        id: playerRespawnTimer
        interval: root.playerRespawnDelayMs
        onTriggered: if (root._health) root._health.revive(root.playerActorId)
    }

    /// Attaque du joueur (touche Espace) : touche l'ennemi vivant le plus
    /// proche dans playerAttackRange.
    function playerAttack() {
        if (!active || !_health || _playerDead) return
        const now = Date.now()
        if (now - _playerLastAttackMs < playerAttackCooldownMs) return
        _playerLastAttackMs = now
        playerAttacked()

        const ps = physicsWorld.bodyState(playerActorId)
        if (!ps.id) return

        let best = null
        let bestDist = playerAttackRange
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
        _health.damage(bodyIdFor(uuid), playerAttackDamage)
        if (_health.isDead(bodyIdFor(uuid))) {
            s.dead = true
            const ep = best.snapableParameters.enemyParameter
            if (ep.respawnEnabled)
                s.respawnAtMs = Date.now() + ep.respawnDelayMs
            stateRevision++
            enemyDied(uuid)
        }
    }

    // ── Tick IA ──────────────────────────────────────────────────────────
    Timer {
        interval: 100
        repeat: true
        running: root.active
        onTriggered: root._aiTick()
    }

    function _aiTick() {
        if (!physicsWorld || !_health) return
        const now = Date.now()
        const ps = physicsWorld.bodyState(playerActorId)
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
                    // Le body est recréé par EnemySpawner (observe stateRevision).
                }
                continue
            }

            const es = physicsWorld.bodyState(bodyId)
            if (!es.id || !ps.id) continue

            if (_playerDead) {
                physicsWorld.pushInput(bodyId, Qt.vector2d(0, 0))
                continue
            }

            const dx = ps.position.x - es.position.x
            const dy = ps.position.y - es.position.y
            const dist = Math.sqrt(dx * dx + dy * dy)

            if (dist <= ep.attackRange) {
                physicsWorld.pushInput(bodyId, Qt.vector2d(0, 0))
                if (now - s.lastAttackMs >= ep.attackCooldownMs) {
                    s.lastAttackMs = now
                    _health.damage(playerActorId, ep.attackDamage)
                    playerHit(uuid, ep.attackDamage)
                }
            } else if (dist <= ep.aggroRange && dist > 0.0001) {
                physicsWorld.pushInput(bodyId,
                                       Qt.vector2d(dx / dist, dy / dist))
            } else {
                physicsWorld.pushInput(bodyId, Qt.vector2d(0, 0))
            }
        }
    }
}
