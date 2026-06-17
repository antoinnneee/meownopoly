/*
 * EditorPhysicsBridge — Phase 3 (zones) + Phase 9 (objets dynamiques)
 *
 * Pont entre l'éditeur QML et le moteur physique Pattounx v2.
 *
 *   ItemSnapableEvents (C++)        EditorPhysicsBridge (ce fichier)
 *   ─────────────────────       →   ─────────────────────────────
 *   tileCreated(tile)               upsertZone si PhysicZoneTile
 *                                   createDynamicCircle si PhysicalObjectTile
 *   tileMoved(tile)                 upsert (debounce ~30 Hz)
 *   zoneParameterChanged(tile)      upsert (debounce ~30 Hz)
 *   tileDeleted(uuid, tileType)     removeZone / removeBody selon tileType
 *
 * Conventions :
 *  - Zones : polygones en coordonnées absolues "unités de grille"
 *      absX = displayParameter.gridRelativePositionX + point.x
 *      absY = displayParameter.gridRelativePositionY + point.y
 *  - Objets dynamiques : centre = origine tile + (unitSizeW/2, unitSizeH/2)
 *      radius = unitSizeWidth / 2.0 (cercle inscrit dans la tile)
 *      mass = 1.0 (pour l'instant ; un futur PhysicalObjectParameter
 *      exposera mass/bounce/friction).
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

    // Période de debounce en ms (= ~30 Hz). Pendant un drag répété, on
    // accumule les events et on n'envoie qu'un seul upsert par tile à
    // l'expiration. Au repos (pas d'event), le dernier état est garanti
    // d'avoir été pushé < `flushIntervalMs` après l'arrêt des mutations.
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
            if (root._isPhysicZone(tile) || root._isPhysicalObject(tile))
                root._enqueueUpsert(tile)
        }
        function onTileMoved(tile) {
            if (root._isPhysicZone(tile) || root._isPhysicalObject(tile))
                root._enqueueUpsert(tile)
        }
        function onZoneParameterChanged(tile) {
            if (!root._isPhysicZone(tile)) return
            root._enqueueUpsert(tile)
        }
        function onPhysicalObjectParameterChanged(tile) {
            if (!root._isPhysicalObject(tile)) return
            root._enqueueUpsert(tile)
        }
        function onTileDeleted(tileId, tileType) {
            if (tileType === ItemSnapable.PhysicZoneTile) {
                root._removeZoneNow(tileId)
            } else if (tileType === ItemSnapable.PhysicalObjectTile) {
                root._removeBodyNow(tileId)
            }
        }
    }

    // Timer de coalescing. Restart à chaque enqueue : tant que les events
    // pleuvent (drag actif), il ne triggere pas. Dès qu'on s'arrête > 33 ms,
    // il flush l'état le plus récent.
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

    function _isPhysicalObject(tile) {
        return tile && tile.tileType === ItemSnapable.PhysicalObjectTile
              && tile.displayParameter
    }

    function _idForTile(tile) {
        // uniqueId est un QUuid → string via toString() inclut les accolades.
        // On garde la forme "{...}" pour cohérence avec d'autres parties C++.
        return tile.uniqueId.toString()
    }

    function _enqueueUpsert(tile) {
        const id = _idForTile(tile)
        _pendingByUuid[id] = tile  // dernier wins
        flushTimer.restart()
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
            if (_isPhysicZone(tile)) _upsertZoneNow(tile)
            else if (_isPhysicalObject(tile)) _upsertObjectNow(tile)
        }
        _pendingByUuid = {}
    }

    function _upsertZoneNow(tile) {
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

    function _upsertObjectNow(tile) {
        if (!_isPhysicalObject(tile)) return
        const dp = tile.displayParameter
        const w  = dp.unitSizeWidth  || 1
        const h  = dp.unitSizeHeight || 1
        // Cercle inscrit dans la tile, centré sur la tile.
        const radius = Math.max(0.05, Math.min(w, h) / 2.0)
        const center = Qt.vector2d(dp.gridRelativePositionX + w / 2.0,
                                   dp.gridRelativePositionY + h / 2.0)

        // PhysicalObjectParameter : extension post-Phase-9. Si présent,
        // on lit mass/bounceFactor/frictionStrength/linearDamping ; sinon
        // on tombe sur les defaults câblés dans physics_world (specFromKinematic).
        // On passe le curseur de friction unique ; physics_world.cpp
        // (specFromKinematic) en dérive staticFriction/dynamicFriction.
        // Le bridge ne fait plus d'arithmétique de friction.
        const pop = tile.physicalObjectParameter
        const params = pop ? {
            bounceFactor:     pop.bounceFactor,
            linearDamping:    pop.linearDamping,
            frictionStrength: pop.frictionStrength
        } : {}
        const mass = pop ? pop.mass : 1.0

        // upsertBody (via createDynamicCircle) : si déjà présent, le worker
        // ne réécrit que la spec (rayon/masse), la position courante est
        // préservée → on appelle setBodyPosition explicitement après pour
        // recoller à la grille.
        const id = _idForTile(tile)
        if (root.verbose) {
            console.log("[EditorPhysicsBridge] upsert object", id,
                        "center=", center.x, center.y,
                        "radius=", radius, "mass=", mass)
        }
        root.physicsWorld.createDynamicCircle(id, center, radius, mass, params)
        root.physicsWorld.setBodyPosition(id, center)
    }

    function _removeZoneNow(tileId) {
        if (!root.physicsWorld) return
        const id = tileId.toString()
        if (_pendingByUuid[id]) delete _pendingByUuid[id]
        if (root.verbose) console.log("[EditorPhysicsBridge] remove zone", id)
        root.physicsWorld.removeZone(id)
    }

    function _removeBodyNow(tileId) {
        if (!root.physicsWorld) return
        const id = tileId.toString()
        if (_pendingByUuid[id]) delete _pendingByUuid[id]
        if (root.verbose) console.log("[EditorPhysicsBridge] remove body", id)
        root.physicsWorld.removeBody(id)
    }
}
