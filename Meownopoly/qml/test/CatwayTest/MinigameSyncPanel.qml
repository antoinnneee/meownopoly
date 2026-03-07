import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GameSession 1.0
import Catway 1.0

Rectangle {
    id: root
    required property var host
    property var selectedPlayer: null

    color: "transparent"

    MinigameSync { id: minigameSync }
    ListModel { id: remotePlayersModel }

    Connections {
        target: minigameSync
        function onPlayerPositionUpdated(playerId, x, y, vx, vy) {
            console.log("onPlayerPositionUpdated")
            for (var i = 0; i < remotePlayersModel.count; i++) {
                if (remotePlayersModel.get(i).pid === playerId) {
                    remotePlayersModel.setProperty(i, "cx", x)
                    remotePlayersModel.setProperty(i, "cy", y)
                    return
                }
            }
            remotePlayersModel.append({ pid: playerId, cx: x, cy: y })
        }
        function onSnapshotReceived(senderId, snapshot) {
            console.log("onSnapshotReceived")
            snapshotLog.text += JSON.stringify({ from: senderId, data: snapshot }) + "\n"
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 300
            Layout.minimumWidth: 300
            color: host.cardBg
            radius: host.cardRadius
            border.color: host.cardBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Mini-jeu (UDP brut)"
                        color: host.textPrimary
                        font.bold: true
                        font.pixelSize: 14
                    }
                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: minigameSync.running ? "#22c55e" : "#ef4444"
                    }
                    Text {
                        text: minigameSync.running ? "running" : "stopped"
                        color: host.textSecondary
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        text: minigameSync.running ? "Stop sync" : "Start sync"
                        implicitHeight: 28
                        implicitWidth: 90
                        background: Rectangle {
                            color: parent.pressed ? host.accent : "#2d2d35"
                            radius: 6
                            border.color: host.cardBorder
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: host.textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                        }
                        onClicked: minigameSync.running ? minigameSync.stop() : minigameSync.start()
                    }
                }

                Text {
                    visible: !!selectedPlayer
                    text: "Peer : " + (selectedPlayer ? selectedPlayer.nickname + " (" + selectedPlayer.playerId + ")" : "")
                    color: host.textSecondary
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                Rectangle {
                    id: gameZone
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#0e0e13"
                    radius: 6
                    clip: true

                    Rectangle {
                        id: localDot
                        width: 32
                        height: 32
                        radius: 16
                        color: "#7c3aed"
                        x: 50
                        y: 50
                        onXChanged: minigameSync.setLocalPosition(localDot.x + 16, localDot.y + 16, 0, 0)
                        onYChanged: minigameSync.setLocalPosition(localDot.x + 16, localDot.y + 16, 0, 0)
                        DragHandler {}
                    }

                    Repeater {
                        model: remotePlayersModel
                        delegate: Item {
                            x: model.cx - 12
                            y: model.cy - 12
                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#f97316"
                            }
                            Text {
                                y: 26
                                text: model.pid.length > 10 ? model.pid.substring(0, 10) : model.pid
                                color: host.textSecondary
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 120
            color: host.cardBg
            radius: host.cardRadius
            border.color: host.cardBorder
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Snapshots reçus"
                        color: host.textPrimary
                        font.bold: true
                        font.pixelSize: 13
                    }
                    Item { Layout.fillWidth: true }
                    Button {
                        visible: GameSession.isHost
                        text: "Envoyer snapshot test"
                        implicitHeight: 26
                        background: Rectangle {
                            color: parent.pressed ? host.accent : "#2d2d35"
                            radius: 6
                            border.color: host.cardBorder
                            border.width: 1
                        }
                        contentItem: Text {
                            text: parent.text
                            color: host.textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 11
                        }
                        onClicked: GameSession.broadcastMinigameSnapshot({ "test": true, "ts": Date.now() })
                    }
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    TextArea {
                        id: snapshotLog
                        readOnly: true
                        wrapMode: Text.Wrap
                        font.pixelSize: 11
                        color: host.textPrimary
                        background: Rectangle {
                            color: "#0e0e13"
                            radius: 4
                            border.color: host.cardBorder
                            border.width: 1
                        }
                    }
                }
            }
        }
    }
}
