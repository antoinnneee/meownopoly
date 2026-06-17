import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import Game
import EditorOpBus

import "../"
import editorBottomPanel
import theme

/*
 * Onglet "Joueurs" du AssetSelectionPanel.
 *
 * Layout : rangée horizontale de cards (PCP_ProfileRow orientation=Horizontal)
 * occupant toute la zone. Le paramétrage d'une classe se fait dans un Popup
 * modal ouvert via le bouton ⚙ de la card (cf. PCP_ProfileCard.editRequested).
 *
 * Le clic simple sur une card ne sert plus qu'à la sélection visuelle —
 * l'édition passe exclusivement par le popup.
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

    // ID du profil en cours d'édition (popup ouvert). Distinct de
    // selectedProfileId pour permettre une sélection visuelle persistante
    // sans forcer l'ouverture du popup.
    property string editingProfileId: ""

    Item {
        id: pageRoot
        anchors.fill: parent
        clip: true

        PCP_ProfileRow {
            id: profileRow
            anchors.fill: parent
            anchors.margins: Screen.pixelDensity * 2
            orientation: Qt.Horizontal
            mapInfo: root.mapInfo
            selectedProfileId: root.selectedProfileId

            onProfileSelected: function(id) {
                root.selectedProfileId = (id === root.selectedProfileId) ? "" : id
            }
            onProfileEditRequested: function(id) {
                root.selectedProfileId = id
                root.editingProfileId = id
                detailPopup.open()
            }
            onProfileAddRequested: {
                if (!root.mapInfo) return
                const before = root.mapInfo.toJSON()
                const p = root.mapInfo.addPlayerProfile()
                Game.updateMapMetadata(before, root.mapInfo.toJSON())
                if (p) {
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
                if (root.editingProfileId === id) {
                    root.editingProfileId = ""
                    detailPopup.close()
                }
            }
            onProfileDuplicateRequested: function(id) {
                if (!root.mapInfo) return
                const before = root.mapInfo.toJSON()
                const p = root.mapInfo.duplicatePlayerProfile(id)
                Game.updateMapMetadata(before, root.mapInfo.toJSON())
                if (p) {
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
    }

    // -------- Popup d'édition --------
    // `parent: Overlay.overlay` → s'affiche au-dessus de toute la fenêtre,
    // pas seulement de pageRoot. Modal pour bloquer l'interaction avec la
    // rangée pendant l'édition (sinon le clic ailleurs déselectionne et
    // PCP_ProfileDetail perd son `profile`).
    Popup {
        id: detailPopup
        parent: Overlay.overlay
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
        padding: 0

        // Dimensions : on remplit la fenêtre (~95 % × 95 %). Pas de cap en
        // cm — les sliders/sections de PCP_ProfileDetail bénéficient de
        // toute la largeur disponible.
        width: parent ? parent.width * 0.95 : 800
        height: parent ? parent.height * 0.95 : 600
        x: parent ? (parent.width - width) / 2 : 0
        y: parent ? (parent.height - height) / 2 : 0

        onClosed: root.editingProfileId = ""

        background: Rectangle {
            color: Theme.background
            radius: Theme.radiusL
            border.color: Theme.surfaceHover
            border.width: 1
        }

        contentItem: Item {
            // Bandeau de titre + bouton fermeture.
            Rectangle {
                id: header
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Screen.pixelDensity * 8
                color: "#222222"
                radius: Theme.radiusL

                // Le radius arrondit aussi le bas du Rectangle, on masque
                // sous la séparation horizontale avec un sous-rect carré.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: parent.radius
                    color: parent.color
                }

                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: Screen.pixelDensity * 3
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const p = root.mapInfo
                                  ? root.mapInfo.playerProfileById(root.editingProfileId)
                                  : null
                        return p ? ("Configurer — " + p.name) : "Configurer"
                    }
                    color: Theme.textSoft
                    font.pixelSize: Math.round(Screen.pixelDensity * 3.6)
                    font.bold: true
                    elide: Text.ElideRight
                }

                ToolButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.rightMargin: Screen.pixelDensity * 1
                    text: "✕"
                    Material.foreground: "#e8e8e8"
                    font.pixelSize: Math.round(Screen.pixelDensity * 4)
                    onClicked: detailPopup.close()
                    implicitWidth: Screen.pixelDensity * 6
                    implicitHeight: Screen.pixelDensity * 6
                }

                // Séparateur sous le header.
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: Theme.surfaceHover
                }
            }

            PCP_ProfileDetail {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: header.bottom
                anchors.bottom: parent.bottom
                profile: root.mapInfo ? root.mapInfo.playerProfileById(
                                            root.editingProfileId)
                                       : null
                mapInfo: root.mapInfo
            }
        }
    }
}
