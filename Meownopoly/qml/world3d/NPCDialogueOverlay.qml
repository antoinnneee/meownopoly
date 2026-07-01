import QtQuick
import ItemSnapable
import NPCParameter
import theme

/*
 * NPCDialogueOverlay — couche visuelle des dialogues PNJ.
 *
 * Enfant de workArea (anchors.fill) : les positions des tiles (t.x/t.y en
 * pixels workArea) suivent pan/zoom sans projection caméra. Trois rendus :
 *  - bulle interactive du PNJ actif du NPCDialogueController (Proximity/Click),
 *  - badges 💬 cliquables des PNJ en mode Click,
 *  - pancartes permanentes des PNJ en mode Always (1re ligne, sans avance).
 */
Item {
    id: root

    /// NPCDialogueController pilotant l'état Proximity/Click.
    property var controller: null
    /// snapableTilesList de l'éditeur.
    property var tilesList: []
    /// Incrémenté par l'hôte sur snapableTilesListUpdated (la mutation par
    /// push() d'une list property n'est pas observée par les bindings).
    property int tilesRevision: 0

    // Tiles PNJ actuellement présentes (re-filtrées à chaque revision).
    readonly property var _npcTiles: {
        tilesRevision
        const out = []
        const list = root.tilesList
        if (!list) return out
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            if (!t || !t.snapableParameters) continue
            if (t.snapableParameters.tileType !== ItemSnapable.NPCTile) continue
            out.push(t)
        }
        return out
    }

    // ── Badges 💬 des PNJ en mode Clic ───────────────────────────────────
    Repeater {
        model: root._npcTiles
        delegate: Rectangle {
            readonly property var tile: modelData
            readonly property var npc: tile.snapableParameters
                                       ? tile.snapableParameters.npcParameter : null
            visible: npc && npc.triggerMode === NPCParameter.Click
                     && npc.dialogueLines.length > 0
            x: tile.x + tile.width - width / 2
            y: tile.y - height / 2
            width: Theme.px(24)
            height: Theme.px(24)
            radius: width / 2
            color: Theme.surface
            border.color: Theme.accent
            border.width: 1

            Text {
                anchors.centerIn: parent
                text: "💬"
                font.pixelSize: Theme.fontSizeSmall
            }

            TapHandler {
                onTapped: if (root.controller) root.controller.openFor(tile)
            }
        }
    }

    // ── Pancartes permanentes (mode Toujours visible) ────────────────────
    Repeater {
        model: root._npcTiles
        delegate: DialogueBox {
            readonly property var tile: modelData
            readonly property var npc: tile.snapableParameters
                                       ? tile.snapableParameters.npcParameter : null
            visible: npc && npc.triggerMode === NPCParameter.Always
                     && npc.dialogueLines.length > 0
            x: tile.x + tile.width / 2 - width / 2
            y: tile.y - height - Theme.spacingXS
            npcName: npc ? npc.npcName : ""
            text: npc && npc.dialogueLines.length > 0 ? npc.dialogueLines[0] : ""
            total: 1
            interactive: false
        }
    }

    // ── Bulle interactive du PNJ actif (Proximity / Click) ───────────────
    DialogueBox {
        readonly property var tile: root.controller ? root.controller.activeNpcTile : null
        readonly property var npc: tile && tile.snapableParameters
                                   ? tile.snapableParameters.npcParameter : null
        visible: tile !== null && npc !== null && npc.dialogueLines.length > 0
        x: tile ? tile.x + tile.width / 2 - width / 2 : 0
        y: tile ? tile.y - height - Theme.spacingXS : 0
        z: 10   // au-dessus des pancartes
        npcName: npc ? npc.npcName : ""
        text: {
            if (!npc || !root.controller) return ""
            const lines = npc.dialogueLines
            const idx = Math.min(root.controller.lineIndex, lines.length - 1)
            return idx >= 0 ? lines[idx] : ""
        }
        index: root.controller ? root.controller.lineIndex : 0
        total: npc ? npc.dialogueLines.length : 0
        interactive: true
        onAdvanceRequested: if (root.controller) root.controller.advance()
    }
}
