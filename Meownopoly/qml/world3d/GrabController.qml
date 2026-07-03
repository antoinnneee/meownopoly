/*
 * GrabController — saisie des caisses (PhysicalObjectTile) à la touche E.
 *
 * Toggle : E attrape la caisse "grabbable" la plus proche (portée = grabRange
 * + rayon de la caisse + rayon du joueur, cf. _radiusOf — sinon une grosse
 * caisse serait physiquement inatteignable, son propre rayon de collision
 * dépassant à lui seul une portée fixe), E à nouveau la relâche. Une caisse
 * tenue est tractée vers un point de maintien près du joueur par un ressort
 * amorti (applyImpulse à ~30 Hz) — jamais de téléportation : la caisse reste
 * un body Dynamic qui respecte les collisions (murs, autres caisses), ce qui
 * permet de la pousser proprement dans une zone "plaque de pression".
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
import "BodyIds.js" as BodyIds

Item {
    id: root
    visible: false

    required property var physicsWorld
    /// CombatController (autorité, localActorId, canal réseau partagé).
    required property var combat
    /// World3D hôte — nécessaire pour convertir la taille (px) des tiles
    /// caisse en cellules de grille (gridManager.gridSize), afin que la
    /// portée de saisie/maintien s'adapte au rayon physique réel de chaque
    /// caisse (une grosse caisse a un rayon de collision qui, ajouté au
    /// rayon du joueur, peut à lui seul dépasser une portée fixe : sans ça
    /// impossible de s'approcher assez près pour la saisir).
    required property var world3D
    /// snapableTilesList de l'éditeur.
    property var tilesList: []
    /// Incrémenté par l'hôte sur snapableTilesListUpdated.
    property int tilesRevision: 0

    /// Portée de saisie et distance de maintien, en cellules de grille —
    /// marge AU-DELÀ du contact surface-à-surface (rayon caisse + rayon
    /// joueur), pas une distance centre-à-centre absolue.
    property real grabRange: 1.6
    property real holdDistance: 0.9
    /// Distance au-delà de laquelle la caisse est lâchée automatiquement
    /// (coincée derrière un mur, joueur téléporté…) — marge au-delà du
    /// point de maintien effectif (cf. _effectiveHoldDistance).
    property real autoReleaseDistance: 3.0
    /// Rayon du joueur (fallback si aucun profil en test) — cf.
    /// LocalPlayerSpawner.radius par défaut.
    property real playerRadius: 0.2
    /// Rayon effectif : celui du profil en test s'il en expose un, sinon
    /// `playerRadius` (même logique que `Editor.qml._resyncMainPlayer`).
    readonly property real _playerRadius:
        (combat && combat.playerProfile && combat.playerProfile.radius !== undefined)
            ? combat.playerProfile.radius : playerRadius

    /// Ressort amorti du maintien (impulsions ~30 Hz) : raideur (fraction de
    /// l'écart au point de maintien convertie en Δv), amortissement (fraction
    /// de la vélocité retranchée) et norme max d'impulsion par unité de masse
    /// (stabilité sur les caisses légères).
    property real springStiffness: 0.5
    property real springDamping: 0.12
    property real maxImpulsePerMass: 2.0

    readonly property bool active: physicsWorld ? physicsWorld.running : false

    // Purge à l'arrêt du moteur : sinon au redémarrage le tick de maintien
    // applique des impulsions de ressort à des caisses que personne ne
    // tient, et `_lastHolder` périmé fausse l'attribution des récompenses
    // de TriggerController.
    onActiveChanged: {
        if (!active) {
            _heldBy = ({})
            _lastHolder = ({})
            grabRevision++
        }
    }

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

    function bodyIdFor(uuid) { return BodyIds.crate(uuid) }

    // Index uuid → tile des caisses, reconstruit avec la liste filtrée —
    // _massOf/_radiusOf sont dans le tick-path 30 Hz du maintien (review Q15).
    readonly property var _crateTileByUuid: {
        const m = ({})
        const tiles = _crateTiles
        for (let i = 0; i < tiles.length; i++)
            m[String(tiles[i].snapableParameters.uniqueId)] = tiles[i]
        return m
    }

    /// Rayon physique réel de la caisse (même formule que
    /// CrateSpawner.bodyRadius — cercle inscrit de la tile × 0.9). Fallback
    /// 0.45 (caisse 1x1) si le gridManager n'est pas encore prêt.
    function _radiusOf(crateUuid) {
        const tile = _crateTileByUuid[String(crateUuid)]
        const gm = root.world3D ? root.world3D.gridManager : null
        const gs = gm ? gm.gridSize : 0
        if (!tile || gs <= 0) return 0.45
        const cellsW = tile.width / gs
        const cellsH = tile.height / gs
        return Math.max(0.1, Math.min(cellsW, cellsH) / 2 * 0.9)
    }

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
        console.log("[GrabController] toggleGrab() actorId=", combat.localActorId,
                    "active=", active, "isAuthority=", combat.isAuthority,
                    "world3D=", !!world3D, "gridManager=", !!(world3D && world3D.gridManager),
                    "gridSize=", (world3D && world3D.gridManager) ? world3D.gridManager.gridSize : "n/a")
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
        if (actorId === "" || !physicsWorld) { console.log("[GrabController] abort: actorId vide ou physicsWorld null"); return }
        const held = _heldBy[actorId]
        if (held) {
            _release(actorId, held)
            return
        }
        const ps = physicsWorld.bodyState(actorId)
        if (!ps.id) { console.log("[GrabController] abort: bodyState(", actorId, ") introuvable"); return }

        let best = ""
        let bestDist = Infinity
        const tiles = _crateTiles
        console.log("[GrabController] tentative depuis", actorId, "@", ps.position,
                    "playerRadius=", _playerRadius, "—", tiles.length, "caisse(s) candidate(s)")
        for (let i = 0; i < tiles.length; i++) {
            const sp = tiles[i].snapableParameters
            if (!sp.physicalObjectParameter.grabbable) { console.log("[GrabController]  caisse", sp.uniqueId, "non grabbable"); continue }
            const uuid = String(sp.uniqueId)
            // Déjà tenue par quelqu'un d'autre ?
            let taken = false
            for (const a in _heldBy) if (_heldBy[a] === uuid) { taken = true; break }
            if (taken) { console.log("[GrabController]  caisse", uuid, "déjà tenue"); continue }
            const cs = physicsWorld.bodyState(bodyIdFor(uuid))
            if (!cs.id) { console.log("[GrabController]  bodyState(", bodyIdFor(uuid), ") introuvable"); continue }
            const dx = cs.position.x - ps.position.x
            const dy = cs.position.y - ps.position.y
            const dist = Math.sqrt(dx * dx + dy * dy)
            // Portée effective = marge de saisie + rayons des deux corps —
            // sinon une grosse caisse serait physiquement impossible à
            // atteindre (son propre rayon de collision dépasserait la portée).
            const radius = _radiusOf(uuid)
            const reach = grabRange + radius + _playerRadius
            console.log("[GrabController]  caisse", uuid, "@", cs.position, "dist =", dist,
                        "radius =", radius, "reach =", reach)
            if (dist <= reach && dist < bestDist) { bestDist = dist; best = uuid }
        }
        if (best === "") { console.log("[GrabController] abort: aucune caisse en portée"); return }
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

            // Rayon de la caisse tenue : le point de maintien et la distance
            // d'auto-relâche doivent rester au-delà de son propre rayon de
            // collision, sinon le ressort vise un point à l'intérieur de la
            // caisse (impossible à atteindre, jitter permanent).
            const crateRadius = _radiusOf(uuid)
            const effectiveHold = Math.max(holdDistance, crateRadius + _playerRadius + 0.15)
            const effectiveRelease = Math.max(autoReleaseDistance, effectiveHold + 1.5)

            const dx = cs.position.x - ps.position.x
            const dy = cs.position.y - ps.position.y
            const dist = Math.sqrt(dx * dx + dy * dy)
            if (dist > effectiveRelease) { _release(actorId, uuid); continue }

            // Point de maintien : à effectiveHold du joueur, dans la
            // direction actuelle de la caisse (elle "traîne" autour de lui).
            const ux = dist > 0.001 ? dx / dist : 1
            const uy = dist > 0.001 ? dy / dist : 0
            const tx = ps.position.x + ux * effectiveHold
            const ty = ps.position.y + uy * effectiveHold

            // Ressort amorti. applyImpulse = Δv × masse côté moteur ; on
            // borne la norme pour rester stable sur les caisses légères.
            const mass = _massOf(uuid)
            let ix = ((tx - cs.position.x) * springStiffness
                      - cs.velocity.x * springDamping) * mass
            let iy = ((ty - cs.position.y) * springStiffness
                      - cs.velocity.y * springDamping) * mass
            const n = Math.sqrt(ix * ix + iy * iy)
            const maxImpulse = maxImpulsePerMass * mass
            if (n > maxImpulse) { ix = ix / n * maxImpulse; iy = iy / n * maxImpulse }
            physicsWorld.applyImpulse(bodyId, Qt.vector2d(ix, iy))
        }
    }

    function _massOf(crateUuid) {
        const tile = _crateTileByUuid[String(crateUuid)]
        if (tile)
            return Math.max(0.01, tile.snapableParameters.physicalObjectParameter.mass)
        return 1.0
    }
}
