import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import EditorOpBus

import "../"
import editorBottomPanel

/*
 * Onglet "Joueurs" du AssetSelectionPanel.
 *
 * Layout : ColumnLayout (rangée horizontale de cards en haut + panneau
 * d'édition en dessous, conditionnel à la sélection).
 *
 * Édition (Phase 4) : mutation locale immédiate (UI réactive + autosave
 * via Game.updateMapMetadata) + EditorOpBus.submitOp pour broadcast
 * collaboratif. En mode solo (EditorSession inactive), submitOp ne
 * fait que logger. En mode collab, l'auteur ne reçoit pas son op
 * rebroadcastée — d'où la mutation locale préservée.
 */
EBP_Content {
    id: root

    required property var logic
    sidePanelRatio: 0   // pas de side panel ; tout est dans mainContent

    readonly property var mapInfo: logic ? logic.mapInfo : null

    // ID du profil sélectionné (string vide = rien). Re-eval auto
    // quand la liste change pour s'aligner sur l'élément sélectionné.
    property string selectedProfileId: ""

    Item {
        id: pageRoot
        anchors.fill: parent
        clip: true

        RowLayout {
            anchors.fill: parent
            anchors.margins: Screen.pixelDensity * 2
            spacing: Screen.pixelDensity * 2

            // ----- Sélection des personnages (gauche, colonne verticale) -----
            PCP_ProfileRow {
                id: profileRow
                orientation: Qt.Vertical
                // ~5 cm de large : assez pour afficher en ligne les 4 boutons
                // d'overlay (↑↓⎘✕) sans débordement, plus la marge / scrollbar.
                Layout.preferredWidth: Screen.pixelDensity * 50
                Layout.fillHeight: true
                mapInfo: root.mapInfo
                selectedProfileId: root.selectedProfileId

                onProfileSelected: function(id) {
                    root.selectedProfileId = (id === root.selectedProfileId) ? "" : id
                }
                onProfileAddRequested: {
                    if (!root.mapInfo) return
                    const before = root.mapInfo.toJSON()
                    const p = root.mapInfo.addPlayerProfile()
                    Game.updateMapMetadata(before, root.mapInfo.toJSON())
                    if (p) {
                        // Broadcast collab : l'op transporte le JSON complet
                        // du profil (avec son UUID) pour reproduction à l'identique.
                        EditorOpBus.submitOp(EditorOpBus.makeAddPlayerProfileOp(
                                                JSON.parse(p.toJsonString())))
                        root.selectedProfileId = p.id
                    }
                }
                onProfileRemoveRequested: function(id) {
                    if (!root.mapInfo) return
                    const before = root.mapInfo.toJSON()
                    root.mapInfo.removePlayerProfile(id)
                    Game.updateMapMetadata(before, root.mapInfo.toJSON())
                    EditorOpBus.submitOp(EditorOpBus.makeRemovePlayerProfileOp(id))
                    if (root.selectedProfileId === id) root.selectedProfileId = ""
                }
                onProfileDuplicateRequested: function(id) {
                    if (!root.mapInfo) return
                    const before = root.mapInfo.toJSON()
                    const p = root.mapInfo.duplicatePlayerProfile(id)
                    Game.updateMapMetadata(before, root.mapInfo.toJSON())
                    if (p) {
                        // Le duplicate génère un nouvel UUID ; on broadcast le
                        // JSON résultant pour que les peers créent l'exact même.
                        EditorOpBus.submitOp(EditorOpBus.makeAddPlayerProfileOp(
                                                JSON.parse(p.toJsonString())))
                        root.selectedProfileId = p.id
                    }
                }
                onProfileMoveRequested: function(id, newIndex) {
                    if (!root.mapInfo) return
                    const before = root.mapInfo.toJSON()
                    if (root.mapInfo.reorderPlayerProfile(id, newIndex)) {
                        Game.updateMapMetadata(before, root.mapInfo.toJSON())
                        EditorOpBus.submitOp(EditorOpBus.makeReorderPlayerProfileOp(
                                                id, newIndex))
                    }
                }
                onProfileRenameRequested: function(id, newName) {
                    if (!root.mapInfo) return
                    const p = root.mapInfo.playerProfileById(id)
                    if (!p || p.name === newName) return
                    const before = root.mapInfo.toJSON()
                    p.name = newName
                    Game.updateMapMetadata(before, root.mapInfo.toJSON())
                    EditorOpBus.submitOp(EditorOpBus.makeUpdatePlayerProfileOp(
                                            id, { "name": newName }))
                }
            }

            // ----- Panneau d'édition (droite) -----
            PCP_ProfileDetail {
                Layout.fillWidth: true
                Layout.fillHeight: true
                profile: root.mapInfo ? root.mapInfo.playerProfileById(root.selectedProfileId)
                                       : null
                mapInfo: root.mapInfo
            }
        }
    }
}
