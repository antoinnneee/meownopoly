import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Game
import EditDelta 1.0
import ItemSnapable
import ItemSnapableFactory
import EditorOpBus 1.0
import NPCParameter
import theme
import ui_item

/*
 * NPCConfigurationPanelSection — panneau de config du PNJ sélectionné
 * (module "config", aux côtés de Case/Zone). Sections NCP_* :
 * identité, séquence de dialogue, déclenchement (+ création de la zone liée).
 *
 * Alimenté par BottomSidePanel.updateSidePanel (sélection simple d'une tile).
 * Chaque édition : mutation directe du NPCParameter C++ → op SetNpcParameter
 * (collab) + Game.updateMap(TileModified) débouncé (persistance/undo).
 */
CollapsableGroupBox {
    id: root
    title: "Configuration de PNJ"

    property bool updatingValues: false
    property var logic: null

    // ItemSnapable C++ du PNJ ciblé (null si sélection ≠ 1 PNJ).
    property var targetSnapable: null
    readonly property var targetNpc: targetSnapable ? targetSnapable.npcParameter : null

    signal focusReleased()

    // Renseigné par updateSidePanel : cible ou efface selon le tileType.
    function setTargetNpc(snapableParameter) {
        if (snapableParameter && snapableParameter.tileType === ItemSnapable.NPCTile) {
            targetSnapable = snapableParameter
            updatingValues = true
            identitySection.updateFromNpcParameter(snapableParameter.npcParameter)
            triggerSection.updateFromNpcParameter(snapableParameter.npcParameter)
            triggerSection.hasLinkedZone = _hasLinkedZone()
            updatingValues = false
        } else {
            targetSnapable = null
        }
    }

    function _hasLinkedZone() {
        if (!targetSnapable) return false
        const nexts = targetSnapable.getNextList()
        for (let i = 0; i < nexts.length; i++) {
            if (nexts[i] && nexts[i].tileType === ItemSnapable.PhysicZoneTile)
                return true
        }
        return false
    }

    // Commit débouncé : une rafale d'éditions (frappe, réordonnancements)
    // ne produit qu'un TileModified (persistance + ApplyState collab).
    Timer {
        id: commitDelayer
        interval: 200
        onTriggered: {
            if (!root.targetSnapable) return
            Game.updateMap(EditDelta.TileModified, root.targetSnapable)
        }
    }

    function _pushNpcUpdate() {
        if (!targetSnapable || !targetNpc || updatingValues) return
        EditorOpBus.recordOp(EditorOpBus.makeSetNpcParameterOp(
            String(targetSnapable.uniqueId),
            JSON.parse(targetNpc.toJSON())))
        commitDelayer.restart()
    }

    // Applique les champs des sections identité/trigger dans le NPCParameter.
    function _applyFormFields() {
        if (!targetNpc || updatingValues) return
        targetNpc.npcName = identitySection.npcName
        targetNpc.visualKind = identitySection.visualKind
        if (identitySection.visualKind === NPCParameter.Model3D)
            targetNpc.modelName = identitySection.modelName
        targetNpc.triggerMode = triggerSection.triggerMode
        _pushNpcUpdate()
    }

    // ── Phase 3 : création + lien de la zone de proximité ─────────────────
    function _createAndLinkZone() {
        if (!targetSnapable || !logic) return
        // Retrouver la tile QML du PNJ (position/lien via connectionManager).
        const tiles = logic.snapableTilesList
        let npcTile = null
        for (let i = 0; i < tiles.length; i++) {
            if (tiles[i] && tiles[i].snapableParameters === targetSnapable) {
                npcTile = tiles[i]
                break
            }
        }
        if (!npcTile) {
            console.warn("[NPCConfig] tile QML du PNJ introuvable")
            return
        }

        const dp = targetSnapable.displayParameter
        const margin = 2   // cellules autour du PNJ
        const w = dp.unitSizeWidth + 2 * margin
        const h = dp.unitSizeHeight + 2 * margin

        const sp = ItemSnapableFactory.createPhysicZone()
        sp.displayParameter.gridRelativePositionX = dp.gridRelativePositionX - margin
        sp.displayParameter.gridRelativePositionY = dp.gridRelativePositionY - margin
        sp.displayParameter.unitSizeWidth = w
        sp.displayParameter.unitSizeHeight = h
        sp.displayParameter.zLayer = 1   // sous les décorations et cases
        sp.displayParameter.zOrder = Game.tickLamport()
        // Rectangle englobant, points RELATIFS à la tile.
        sp.zoneParameter.addPoint(0, 0)
        sp.zoneParameter.addPoint(w, 0)
        sp.zoneParameter.addPoint(w, h)
        sp.zoneParameter.addPoint(0, h)
        // exclusion=false → la zone émet actorEnteredZone/ExitedZone
        // (une zone exclusion est un mur, pas un trigger).
        sp.zoneParameter.exclusion = false
        sp.zoneParameter.zoneColor = "#3F51B5"
        sp.zoneParameter.zoneName =
            (targetNpc && targetNpc.npcName !== "" ? targetNpc.npcName : "PNJ") + " (proximité)"

        const zoneTile = logic.tileLogic.createItemSnapableTile(sp)
        if (!zoneTile) {
            console.warn("[NPCConfig] échec de création de la zone de proximité")
            return
        }
        if (zoneTile.updateDisplayBounds) zoneTile.updateDisplayBounds()
        Game.updateMap(EditDelta.TileAdded, zoneTile.snapableParameters)

        // Lien PNJ --next--> zone : même chemin que l'UI de connexions
        // (addNextElement pose symétriquement prev côté zone), puis
        // TileModified pour persister/broadcaster le lien.
        npcTile.connectionManager.addNextElement(zoneTile)
        Game.updateMap(EditDelta.TileModified, targetSnapable)

        triggerSection.hasLinkedZone = true
    }

    content: [
        Text {
            visible: root.targetSnapable === null
            text: "Sélectionnez un PNJ pour le configurer."
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
            font.italic: true
        },

        NCP_IdentitySection {
            id: identitySection
            visible: root.targetSnapable !== null
            Layout.fillWidth: true
            updatingValues: root.updatingValues
            onFieldEdited: root._applyFormFields()
        },

        NCP_DialogueSection {
            id: dialogueSection
            visible: root.targetSnapable !== null
            Layout.fillWidth: true
            targetNpc: root.targetNpc
            onLinesEdited: root._pushNpcUpdate()
            onFocusReleased: root.focusReleased()
        },

        NCP_TriggerSection {
            id: triggerSection
            visible: root.targetSnapable !== null
            Layout.fillWidth: true
            updatingValues: root.updatingValues
            onFieldEdited: root._applyFormFields()
            onCreateZoneRequested: root._createAndLinkZone()
        }
    ]
}
