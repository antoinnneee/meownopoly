import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GameSession 1.0
import Catway 1.0
import Meownopoly.Account 1.0

Rectangle {
    id: root
    required property var host
    property var selectedPlayer: null
    color: "transparent"

    onSelectedPlayerChanged: {
        if (selectedPlayer && gameSessionPanel)
            gameSessionPanel.hostPlayerId = selectedPlayer.playerId
    }

    Connections {
        target: GameSession
        function onMapSyncReceived(senderId, mapJson) {
            if (mapSyncCard) {
                mapSyncCard.lastMapSyncSenderText = senderId
                mapSyncCard.lastMapSyncSummaryText = "(" + Object.keys(mapJson).length + " clés)"
            }
        }
        function onBoardEventReceived(type, senderId, payload) {
            if (boardEventsCard && boardEventsCard.boardEventLog) {
                var hex = "0x" + type.toString(16).toUpperCase().padStart(2, "0")
                boardEventsCard.boardEventLog.text += "[type=" + hex + "] from: " + senderId + " — " + JSON.stringify(payload) + "\n"
            }
        }
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

            // ── Colonne 0 — Joueurs connectés ────────────────────────────────
            Item {
                SplitView.preferredWidth: 280
                SplitView.minimumWidth: 200

                UdpPlayersPanel {
                    anchors.fill: parent
                    anchors.margins: 4
                    host: root.host
                    selectedPlayer: root.selectedPlayer
                    onPlayerClicked: function(player) {
                        root.selectedPlayer = player
                    }
                }
            }

            // ── Colonne 1 — Session ───────────────────────────────────────────
            Item {
                SplitView.minimumWidth: 220
                SplitView.preferredWidth: 250

                GameSessionPanel {
                    id: gameSessionPanel
                    anchors.fill: parent
                    anchors.margins: 4
                    host: root.host
                    selectedPlayerVisible: !!root.selectedPlayer
                }
            }

            // ── Colonne 2 — Mini-jeu UDP brut ────────────────────────────────
            Item {
                SplitView.fillWidth: true
                SplitView.minimumWidth: 300

                MinigameSyncPanel {
                    anchors.fill: parent
                    host: root.host
                    selectedPlayer: root.selectedPlayer
                }
            }

            // ── Colonne 3 — Reliable Events + MapSync ────────────────────────
            Item {
                SplitView.minimumWidth: 250
                SplitView.preferredWidth: 300

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 8

                    MapSyncCard {
                        id: mapSyncCard
                        Layout.fillWidth: true
                        host: root.host
                    }

                    BoardEventsCard {
                        id: boardEventsCard
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        host: root.host
                    }
                }
            }
        }
    }
}
