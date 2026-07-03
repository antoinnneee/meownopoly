/*
 * EditorPhysicsBridge — Phase 3 (zones)
 *
 * Pont entre l'éditeur QML et le moteur physique Pattounx v2.
 *
 *   ItemSnapableEvents (C++)        EditorPhysicsBridge (ce fichier)
 *   ─────────────────────       →   ─────────────────────────────
 *   tileCreated(tile)               upsertZone si PhysicZoneTile
 *   tileMoved(tile)                 upsert (debounce ~30 Hz)
 *   zoneParameterChanged(tile)      upsert (debounce ~30 Hz)
 *   tileDeleted(uuid, tileType)     removeZone si PhysicZoneTile
 *
 * Conventions :
 *  - Zones : polygones en coordonnées absolues "unités de grille"
 *      absX = displayParameter.gridRelativePositionX + point.x
 *      absY = displayParameter.gridRelativePositionY + point.y
 *
 * Le PhysicsWorld n'impose aucun système d'unités — on reste cohérent
 * avec PhysicsTestTab qui utilise déjà des Qt.vector2d(gridX, gridY).
 */
import QtQuick
import Pattounx 1.0
import ItemSnapable

Item {
    id: root

    // Cible : moteur physique à alimenter. Doit être assigné par l'appelant.
    property var physicsWorld: null

    // Période de throttle en ms (= ~30 Hz). Pendant un drag répété, on
    // accumule les events et on flush l'état le plus récent au plus une
    // fois par période — throttle LEADING : le timer démarre au premier
    // event et n'est PAS repoussé par les suivants (un restart à chaque
    // event ferait un trailing debounce → zéro sync pendant tout un drag
    // continu, zone fantôme dans le moteur). Au repos, le dernier état est
    // garanti pushé < `flushIntervalMs` après l'arrêt des mutations.
    property int flushIntervalMs: 33

    // Logs (optionnel) — utile en bring-up Phase 3 et tests collab.
    property bool verbose: false

    // Set des tile uuid en attente de flush. Les ops "remove" sont
    // émises immédiatement (pas de debounce) pour éviter qu'une zone
    // supprimée continue de bloquer un actor le temps du timer.
    property var _pendingByUuid: ({})

    // Connexion au flux d'événements C++.
    Connections {
        target: ItemSnapableEvents

        function onTileCreated(tile) {
            if (root._isPhysicZone(tile))
                root._enqueueUpsert(tile)
        }
        function onTileMoved(tile) {
            if (root._isPhysicZone(tile))
                root._enqueueUpsert(tile)
        }
        function onZoneParameterChanged(tile) {
            if (!root._isPhysicZone(tile)) return
            root._enqueueUpsert(tile)
        }
        function onTileDeleted(tileId, tileType) {
            if (tileType === ItemSnapable.PhysicZoneTile)
                root._removeZoneNow(tileId)
        }
    }

    // Timer de coalescing. Démarré au premier enqueue d'une fenêtre, jamais
    // repoussé : les events d'un drag actif s'accumulent et sont flushés
    // toutes les ~33 ms (l'event suivant le flush ré-arme le timer).
    Timer {
        id: flushTimer
        interval: root.flushIntervalMs
        repeat: false
        onTriggered: root._flushPending()
    }

    function flushNow() {
        flushTimer.stop()
        _flushPending()
    }

    // ----- internes -----

    function _isPhysicZone(tile) {
        return tile && tile.tileType === ItemSnapable.PhysicZoneTile
              && tile.zoneParameter
    }

    function _idForTile(tile) {
        // uniqueId est un QUuid → string via toString() inclut les accolades.
        // On garde la forme "{...}" pour cohérence avec d'autres parties C++.
        return tile.uniqueId.toString()
    }

    function _enqueueUpsert(tile) {
        const id = _idForTile(tile)
        _pendingByUuid[id] = tile  // dernier wins
        if (!flushTimer.running) flushTimer.start()
    }

    function _flushPending() {
        if (!root.physicsWorld) {
            if (root.verbose) console.warn("[EditorPhysicsBridge] physicsWorld non assigné, flush ignoré")
            return
        }
        const ids = Object.keys(_pendingByUuid)
        for (let i = 0; i < ids.length; i++) {
            const tile = _pendingByUuid[ids[i]]
            if (!tile) continue
            if (_isPhysicZone(tile)) upsertZoneNow(tile)
        }
        _pendingByUuid = {}
    }

    /// Upsert immédiat (sans throttle) d'une zone dans le moteur. API
    /// PUBLIQUE : aussi consommée par TriggerController pour re-fermer les
    /// "portes" (zones d'exclusion liées) à la désactivation d'une plaque.
    function upsertZoneNow(tile) {
        if (!_isPhysicZone(tile)) return
        const zp = tile.zoneParameter
        const dp = tile.displayParameter
        const ox = dp ? dp.gridRelativePositionX : 0
        const oy = dp ? dp.gridRelativePositionY : 0

        const localPoints = zp.polygonPoints || []
        if (localPoints.length < 3) {
            // Polygone dégénéré : retirer la zone si présente, sinon no-op.
            // C'est utile pendant la création (premier point posé).
            root.physicsWorld.removeZone(_idForTile(tile))
            return
        }
        const absPoints = []
        for (let i = 0; i < localPoints.length; i++) {
            const p = localPoints[i]
            absPoints.push(Qt.vector2d(ox + p.x, oy + p.y))
        }

        const params = {
            exclusion: zp.exclusion,
            // Une zone exclusion n'a pas vocation à émettre des events
            // enter/exit (c'est juste un mur). Une zone non-exclusion sert
            // typiquement de trigger ou de modificateur de friction/vitesse.
            trigger: !zp.exclusion,
            frictionStrength: zp.frictionStrength,
            speedMultiplier: zp.speedMultiplier,
            accelerationMultiplier: zp.accelerationMultiplier,
            velocityForce: Qt.vector2d(
                zp.velocityDirection.x * zp.velocityStrength,
                zp.velocityDirection.y * zp.velocityStrength)
        }

        if (root.verbose) {
            console.log("[EditorPhysicsBridge] upsert zone", _idForTile(tile),
                        "n=", absPoints.length, "exclusion=", params.exclusion)
        }
        root.physicsWorld.upsertZone(_idForTile(tile), absPoints, params)
    }

    function _removeZoneNow(tileId) {
        if (!root.physicsWorld) return
        const id = tileId.toString()
        if (_pendingByUuid[id]) delete _pendingByUuid[id]
        if (root.verbose) console.log("[EditorPhysicsBridge] remove zone", id)
        root.physicsWorld.removeZone(id)
    }
}
