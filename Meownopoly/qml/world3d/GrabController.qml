/*
 * GrabController — saisie des caisses (PhysicalObjectTile) à la touche E.
 *
 * Toggle : E attrape la caisse "grabbable" la plus proche (≤ grabRange),
 * E à nouveau la relâche. Une caisse tenue est tractée vers un point de
 * maintien près du joueur par un ressort amorti (applyImpulse à ~30 Hz) —
 * jamais de téléportation : la caisse reste un body Dynamic qui respecte
 * les collisions (murs, autres caisses), ce qui permet de la pousser
 * proprement dans une zone "plaque de pression".
 *
 * Résolution host-authoritative (même modèle que CombatController) :
 *  - autorité : résout les toggles, applique les impulsions de maintien,
 *    broadcast l'état {type:"grabState", actorId, crate} ;
 *  - client : envoie {type:"grab", actorId} via le canal combat de
 *    PhysicsSession et applique les grabState reçus (suivi lastHolder).
 *
 * `lastHolderOf(crateUuid)` mémorise le dernier porteur de chaque caisse —
 * utilisé par TriggerController pour attribuer les récompenses.
 */
import QtQuick
import ItemSnapable
import Pattounx 1.0

Item {
    id: root
    visible: false

    required property var physicsWorld
    /// CombatController (autorité, localActorId, canal réseau partagé).
    required property var combat
    /// snapableTilesList de l'éditeur.
    property var tilesList: []
    /// Incrémenté par l'hôte sur snapableTilesListUpdated.
    property int tilesRevision: 0

    /// Portée de saisie et distance de maintien, en cellules de grille.
    property real grabRange: 1.6
    property real holdDistance: 0.9
    /// Distance au-delà de laquelle la caisse est lâchée automatiquement
    /// (coincée derrière un mur, joueur téléporté…).
    property real autoReleaseDistance: 3.0

    readonly property bool active: physicsWorld ? physicsWorld.running : false

    // actorId → uuid de caisse tenue (autorité : vérité ; client : miroir).
    property var _heldBy: ({})
    // uuid de caisse → dernier actorId porteur (attribution des récompenses).
    property var _lastHolder: ({})
    // Re-déclenche les bindings des overlays (mutations en place non vues).
    property int grabRevision: 0

    signal crateGrabbed(string actorId, string crateUuid)
    signal crateReleased(string actorId, string crateUuid)

    readonly property var _crateTiles: {
        tilesRevision
        const out = []
        const list = root.tilesList
        if (!list) return out
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            const sp = t ? t.snapableParameters : null
            if (!sp || sp.tileType !== ItemSnapable.PhysicalObjectTile) continue
            out.push(t)
        }
        return out
    }

    function bodyIdFor(uuid) { return "crate:" + uuid }

    /// uuid de la caisse tenue par le joueur local ("" si aucune).
    function heldByLocal() {
        grabRevision
        return _heldBy[combat.localActorId] || ""
    }

    /// Dernier porteur d'une caisse ("" si jamais tenue).
    function lastHolderOf(crateUuid) {
        return _lastHolder[String(crateUuid)] || ""
    }

    /// Touche E : toggle local (autorité) ou requête à l'hôte (client).
    function toggleGrab() {
        if (!active) return
        if (!combat.isAuthority) {
            PhysicsSession.sendCombatRequest({
                type: "grab", actorId: combat.localActorId
            })
            return
        }
        _resolveGrabToggle(combat.localActorId)
    }

    /// Autorité : résout un toggle grab pour un actor (local ou distant).
    function _resolveGrabToggle(actorId) {
        if (actorId === "" || !physicsWorld) return
        const held = _heldBy[actorId]
        if (held) {
            _release(actorId, held)
            return
        }
        const ps = physicsWorld.bodyState(actorId)
        if (!ps.id) return

        let best = ""
        let bestDist = grabRange
        const tiles = _crateTiles
        for (let i = 0; i < tiles.length; i++) {
            const sp = tiles[i].snapableParameters
            if (!sp.physicalObjectParameter.grabbable) continue
            const uuid = String(sp.uniqueId)
            // Déjà tenue par quelqu'un d'autre ?
            let taken = false
            for (const a in _heldBy) if (_heldBy[a] === uuid) { taken = true; break }
            if (taken) continue
            const cs = physicsWorld.bodyState(bodyIdFor(uuid))
            if (!cs.id) continue
            const dx = cs.position.x - ps.position.x
            const dy = cs.position.y - ps.position.y
            const dist = Math.sqrt(dx * dx + dy * dy)
            if (dist <= bestDist) { bestDist = dist; best = uuid }
        }
        if (best === "") return
        _heldBy[actorId] = best
        _lastHolder[best] = actorId
        grabRevision++
        crateGrabbed(actorId, best)
        if (combat.networked) {
            PhysicsSession.broadcastCombatEvent({
                type: "grabState", actorId: actorId, crate: best
            })
        }
    }

    function _release(actorId, crateUuid) {
        delete _heldBy[actorId]
        grabRevision++
        crateReleased(actorId, crateUuid)
        if (combat.isAuthority && combat.networked) {
            PhysicsSession.broadcastCombatEvent({
                type: "grabState", actorId: actorId, crate: ""
            })
        }
    }

    // ── Réseau : requêtes (hôte) et état (client) ─────────────────────────
    Connections {
        target: PhysicsSession
        function onCombatRequestReceived(senderId, req) {
            if (!root.combat.isAuthority || !root.active) return
            if (req.type === "grab")
                root._resolveGrabToggle(String(req.actorId || ""))
        }
        function onCombatEventReceived(ev) {
            if (root.combat.isAuthority || !ev) return
            if (ev.type !== "grabState") return
            const actorId = String(ev.actorId)
            const crate = String(ev.crate || "")
            if (crate === "") {
                delete root._heldBy[actorId]
            } else {
                root._heldBy[actorId] = crate
                root._lastHolder[crate] = actorId
            }
            root.grabRevision++
        }
    }

    // ── Tick de maintien (autorité) : ressort amorti vers le hold point ──
    Timer {
        interval: 33
        repeat: true
        running: root.active && root.combat.isAuthority
        onTriggered: root._holdTick()
    }

    function _holdTick() {
        if (!physicsWorld) return
        for (const actorId in _heldBy) {
            const uuid = _heldBy[actorId]
            const bodyId = bodyIdFor(uuid)
            const ps = physicsWorld.bodyState(actorId)
            const cs = physicsWorld.bodyState(bodyId)
            if (!ps.id || !cs.id) { _release(actorId, uuid); continue }

            const dx = cs.position.x - ps.position.x
            const dy = cs.position.y - ps.position.y
            const dist = Math.sqrt(dx * dx + dy * dy)
            if (dist > autoReleaseDistance) { _release(actorId, uuid); continue }

            // Point de maintien : à holdDistance du joueur, dans la
            // direction actuelle de la caisse (elle "traîne" autour de lui).
            const ux = dist > 0.001 ? dx / dist : 1
            const uy = dist > 0.001 ? dy / dist : 0
            const tx = ps.position.x + ux * holdDistance
            const ty = ps.position.y + uy * holdDistance

            // Ressort amorti. applyImpulse = Δv × masse côté moteur ; on
            // borne la norme pour rester stable sur les caisses légères.
            const mass = _massOf(uuid)
            let ix = ((tx - cs.position.x) * 0.5 - cs.velocity.x * 0.12) * mass
            let iy = ((ty - cs.position.y) * 0.5 - cs.velocity.y * 0.12) * mass
            const n = Math.sqrt(ix * ix + iy * iy)
            const maxImpulse = 2.0 * mass
            if (n > maxImpulse) { ix = ix / n * maxImpulse; iy = iy / n * maxImpulse }
            physicsWorld.applyImpulse(bodyId, Qt.vector2d(ix, iy))
        }
    }

    function _massOf(crateUuid) {
        const tiles = _crateTiles
        for (let i = 0; i < tiles.length; i++) {
            const sp = tiles[i].snapableParameters
            if (String(sp.uniqueId) === crateUuid)
                return Math.max(0.01, sp.physicalObjectParameter.mass)
        }
        return 1.0
    }
}
