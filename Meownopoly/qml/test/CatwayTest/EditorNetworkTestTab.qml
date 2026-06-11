import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EditorSession 1.0
import Catway 1.0
import theme

Rectangle {
    id: root
    required property var host
    property var selectedPlayer: null
    color: "transparent"

    onSelectedPlayerChanged: {
        if (selectedPlayer && editorSessionPanel)
            editorSessionPanel.hostPlayerId = selectedPlayer.playerId
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        SplitView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: Qt.Horizontal

            handle: Rectangle {
                implicitWidth: 8
                color: "transparent"
                Rectangle {
                    width: 2
                    height: parent.height
                    anchors.centerIn: parent
                    color: root.host.cardBorder
                    radius: 1
                }
            }

            // ── Colonne 0 — Joueurs P2P ──────────────────────────────────────
            Item {
                SplitView.preferredWidth: 280
                SplitView.minimumWidth: 200

                UdpPlayersPanel {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    host: root.host
                    selectedPlayer: root.selectedPlayer
                    onPlayerClicked: function(player) {
                        root.selectedPlayer = player
                    }
                }
            }

            // ── Colonne 1 — Session éditeur ──────────────────────────────────
            Item {
                SplitView.minimumWidth: 240
                SplitView.preferredWidth: 280

                EditorSessionPanel {
                    id: editorSessionPanel
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    host: root.host
                    selectedPlayerVisible: !!root.selectedPlayer
                }
            }

            // ── Colonne 2 — Log d'ops ────────────────────────────────────────
            Item {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 300

                EditorOpsCard {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXS
                    host: root.host
                }
            }
        }
    }
}
