/*
 * TriggerController — zones "plaque de pression" (ZoneParameter.triggerMode
 * == 1, zones non-exclusion) activées par les caisses (PhysicalObjectTile).
 *
 * Détection : le moteur émet actorEnteredZone/actorExitedZone pour TOUT body
 * (les caisses "crate:<uuid>" incluses). L'autorité suit l'ensemble des
 * caisses présentes par zone trigger ; la zone est active dès qu'au moins
 * une caisse est dedans.
 *
 * Effets à l'activation (cibles = éléments liés `next` de la zone) :
 *  - cible zone d'exclusion → "porte ouverte" : zone retirée du moteur
 *    (removeZone), re-upsertée via l'EditorPhysicsBridge à la désactivation
 *    (sauf triggerOnce). Feedback 2D : tile estompée.
 *  - cible décoration → estompée (runtime uniquement, jamais persisté).
 *  - récompense (rewardCurrency / rewardItemName) créditée UNE SEULE FOIS
 *    par session au dernier porteur de la caisse déclencheuse (fallback
 *    joueur local de l'autorité), via CombatController.applyLoot (modules
 *    monnaie/inventaire).
 *
 * Réseau : l'autorité broadcast {type:"zoneTrigger", uuid, active} (visuel +
 * portes côté client) et {type:"loot", ...} (miroirs de modules) sur le
 * canal combat de PhysicsSession.
 */
import QtQuick
import ItemSnapable
import Pattounx 1.0
import "BodyIds.js" as BodyIds

Item {
    id: root
    visible: false

    required property var physicsWorld
    /// CombatController (autorité, applyLoot, localActorId).
    required property var combat
    /// GrabController (lastHolderOf pour l'attribution des récompenses).
    property var grab: null
    /// EditorPhysicsBridge (re-upsert des zones "portes" à la fermeture).
    property var physicsBridge: null
    /// snapableTilesList de l'éditeur.
    property var tilesList: []
    /// Incrémenté par l'hôte sur snapableTilesListUpdated.
    property int tilesRevision: 0

    readonly property bool active: physicsWorld ? physicsWorld.running : false

    // uuid zone → { crates: {uuid:true}, active, latched, rewarded }
    property var _states: ({})
    // Re-déclenche les bindings d'overlays.
    property int triggerRevision: 0

    signal zoneActivated(string zoneUuid)
    signal zoneDeactivated(string zoneUuid)

    readonly property var _triggerZoneTiles: {
        tilesRevision
        const out = []
        const list = root.tilesList
        if (!list) return out
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            const sp = t ? t.snapableParameters : null
            if (!sp || sp.tileType !== ItemSnapable.PhysicZoneTile) continue
            if (!sp.zoneParameter || sp.zoneParameter.triggerMode !== 1) continue
            out.push(t)
        }
        return out
    }

    function isZoneActive(zoneUuid) {
        triggerRevision
        const s = _states[String(zoneUuid)]
        return !!(s && s.active)
    }

    function _stateFor(uuid) {
        let s = _states[uuid]
        if (!s) {
            s = { crates: ({}), active: false, latched: false, rewarded: false }
            _states[uuid] = s
        }
        return s
    }

    // Index uuid → tile (liste complète + zones trigger), reconstruits par
    // revision — _triggerTileForZoneId est dans le chemin chaud des events
    // enter/exit du moteur (review Q15).
    readonly property var _tilesByUuidMap: {
        tilesRevision
        const m = ({})
        const list = root.tilesList
        if (!list) return m
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            if (t && t.snapableParameters)
                m[String(t.snapableParameters.uniqueId)] = t
        }
        return m
    }
    readonly property var _triggerTileByUuidMap: {
        const m = ({})
        const zones = _triggerZoneTiles
        for (let i = 0; i < zones.length; i++)
            m[String(zones[i].snapableParameters.uniqueId)] = zones[i]
        return m
    }

    function _tileByUuid(uuid) {
        return _tilesByUuidMap[String(uuid)] || null
    }

    // Les ids de zone du moteur sont les uniqueId AVEC accolades
    // (EditorPhysicsBridge._idForTile). Les uuid de tiles côté QML aussi
    // (String(uniqueId) === "{...}") — comparaison directe.
    function _triggerTileForZoneId(zoneId) {
        return _triggerTileByUuidMap[String(zoneId)] || null
    }

    // ── Détection (autorité uniquement — le moteur ne tourne que chez elle) ─
    Connections {
        target: root.physicsWorld
        function onActorEnteredZone(actorId, zoneId) {
            if (!root.combat.isAuthority) return
            if (!BodyIds.isCrate(actorId)) return
            const tile = root._triggerTileForZoneId(String(zoneId))
            if (!tile) return
            const zUuid = String(tile.snapableParameters.uniqueId)
            const s = root._stateFor(zUuid)
            s.crates[String(actorId)] = true
            root._evaluate(tile, s, BodyIds.crateUuid(actorId))
        }
        function onActorExitedZone(actorId, zoneId) {
            if (!root.combat.isAuthority) return
            if (!BodyIds.isCrate(actorId)) return
            const tile = root._triggerTileForZoneId(String(zoneId))
            if (!tile) return
            const zUuid = String(tile.snapableParameters.uniqueId)
            const s = root._stateFor(zUuid)
            delete s.crates[String(actorId)]
            root._evaluate(tile, s, "")
        }
    }

    // Moteur arrêté → tout refermer proprement (retour au mode édition).
    onActiveChanged: {
        if (active) return
        for (const uuid in _states) {
            const s = _states[uuid]
            if (s.active) {
                const tile = _tileByUuid(uuid)
                if (tile) _applyTargets(tile, false)
            }
        }
        _states = ({})
        triggerRevision++
    }

    /// Ré-évalue l'état d'une zone après entrée/sortie d'une caisse.
    /// `triggerCrateUuid` : caisse à l'origine d'une activation (récompense).
    function _evaluate(tile, s, triggerCrateUuid) {
        const zp = tile.snapableParameters.zoneParameter
        const zUuid = String(tile.snapableParameters.uniqueId)
        const occupied = Object.keys(s.crates).length > 0
        const wantActive = occupied || s.latched

        if (wantActive && !s.active) {
            s.active = true
            if (zp.triggerOnce) s.latched = true
            _applyTargets(tile, true)
            _grantReward(tile, s, triggerCrateUuid)
            triggerRevision++
            zoneActivated(zUuid)
            _broadcast(zUuid, true)
        } else if (!wantActive && s.active) {
            s.active = false
            _applyTargets(tile, false)
            triggerRevision++
            zoneDeactivated(zUuid)
            _broadcast(zUuid, false)
        }
    }

    function _broadcast(zoneUuid, isActive) {
        if (combat.isAuthority && combat.networked) {
            PhysicsSession.broadcastCombatEvent({
                type: "zoneTrigger", uuid: zoneUuid, active: isActive
            })
        }
    }

    /// Ouvre/ferme les cibles liées (next) de la zone trigger.
    function _applyTargets(tile, open) {
        const sp = tile.snapableParameters
        const targets = sp.getNextList()
        for (let i = 0; i < targets.length; i++) {
            const target = targets[i]
            if (!target) continue
            const tUuid = String(target.uniqueId)
            const el = _tileByUuid(tUuid)

            if (target.tileType === ItemSnapable.PhysicZoneTile) {
                // Porte physique : zone retirée du moteur à l'ouverture,
                // re-upsertée à la fermeture (bridge, mêmes coordonnées).
                // Autorité seulement : côté client la sim locale est OFF,
                // les zones du moteur local ne servent à rien (l'état vient
                // des snapshots de l'hôte) — cf. review Q12.
                if (combat.isAuthority) {
                    if (open) {
                        physicsWorld.removeZone(tUuid)
                    } else if (physicsBridge) {
                        physicsBridge.upsertZoneNow(target)
                    }
                }
            }
            // Feedback 2D runtime (jamais persisté). Set impératif assumé :
            // il écraserait un binding `opacity` posé ailleurs sur la tile —
            // aucun n'existe aujourd'hui, et l'état est restauré (1.0) à la
            // fermeture/au stop.
            if (el) el.opacity = open ? 0.35 : 1.0
        }
    }

    /// Récompense one-shot au dernier porteur de la caisse déclencheuse.
    function _grantReward(tile, s, triggerCrateUuid) {
        if (s.rewarded) return
        const zp = tile.snapableParameters.zoneParameter
        const currency = zp.rewardCurrency
        const itemName = zp.rewardItemName
        if (currency <= 0 && itemName === "") return
        s.rewarded = true

        let to = ""
        if (grab && triggerCrateUuid !== "")
            to = grab.lastHolderOf(triggerCrateUuid)
        if (to === "") to = combat.localActorId

        combat.applyLoot(to, currency, itemName, zp.rewardItemQuantity)
        if (combat.networked) {
            PhysicsSession.broadcastCombatEvent({
                type: "loot", to: to, currency: currency,
                itemName: itemName, itemQuantity: zp.rewardItemQuantity
            })
        }
    }

    // ── Client : applique les zoneTrigger reçus (portes + visuel) ────────
    Connections {
        target: PhysicsSession
        function onCombatEventReceived(ev) {
            if (root.combat.isAuthority || !ev) return
            if (ev.type !== "zoneTrigger") return
            const zUuid = String(ev.uuid)
            const tile = root._tileByUuid(zUuid)
            if (!tile) return
            const s = root._stateFor(zUuid)
            s.active = !!ev.active
            root._applyTargets(tile, s.active)
            root.triggerRevision++
            if (s.active) root.zoneActivated(zUuid)
            else root.zoneDeactivated(zUuid)
        }
    }
}
