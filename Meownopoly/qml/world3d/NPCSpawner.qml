import QtQuick
import QtQuick3D
import ItemSnapable
import NPCParameter

/*
 * NPCSpawner — instancie un node 3D statique par NPCTile en mode Model3D.
 *
 * Pas de body physique : c'est le joueur qui entre dans la zone de trigger,
 * le PNJ n'a pas besoin d'un corps Pattounx — juste un SkinnedModel figé.
 * Les PNJ en mode Sprite2D ne sont PAS répliqués en 3D : leur rendu 2D
 * (SnapableNPC) est déjà visible sous la View3D transparente.
 *
 * Position : lit tile.x/tile.y (pixels workArea, à jour pendant un drag —
 * cf. gotcha "pixels vs grille") convertis en coords grille puis monde via
 * gridToWorldStable. La dépendance explicite à world3D._gridBasis re-évalue
 * le binding quand le mapping affine est (re)calibré.
 */
Item {
    id: root
    visible: false

    /// World3D hôte (scene + helpers de conversion).
    required property var world3D
    /// snapableTilesList de l'éditeur.
    property var tilesList: []
    /// Incrémenté par l'hôte sur snapableTilesListUpdated.
    property int tilesRevision: 0

    readonly property var _modelNpcTiles: {
        tilesRevision
        const out = []
        const list = root.tilesList
        if (!list) return out
        for (let i = 0; i < list.length; i++) {
            const t = list[i]
            const sp = t ? t.snapableParameters : null
            if (!sp || sp.tileType !== ItemSnapable.NPCTile) continue
            const npc = sp.npcParameter
            if (!npc || npc.visualKind !== NPCParameter.Model3D) continue
            if (npc.modelName === "") continue
            out.push(t)
        }
        return out
    }

    Instantiator {
        model: root._modelNpcTiles

        delegate: Node {
            id: npcNode
            parent: root.world3D ? root.world3D.scene : null

            readonly property var tile: modelData
            readonly property var npc: tile && tile.snapableParameters
                                       ? tile.snapableParameters.npcParameter : null

            position: {
                const w3d = root.world3D
                if (!w3d || !tile) return Qt.vector3d(0, 0, 0)
                w3d._gridBasis   // re-calibrage du mapping affine → re-évaluer
                const gm = w3d.gridManager
                const gs = gm ? gm.gridSize : 0
                if (gs <= 0) return Qt.vector3d(0, 0, 0)
                // Centre de la tile, en unités de grille (pixels courants /
                // gridSize — suit le drag en continu).
                const gx = (tile.x + tile.width / 2) / gs
                const gy = (tile.y + tile.height / 2) / gs
                return w3d.gridToWorldStable(gx, gy)
            }

            SkinnedModel {
                modelName: npcNode.npc ? npcNode.npc.modelName : ""
            }
        }
    }
}
