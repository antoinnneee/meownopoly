import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0

ColumnLayout {
    id: panelRoot
    required property var host
    property var selectedPlayer: null

    signal playerClicked(var player)

    spacing: 12

    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredHeight: panelRoot.height - playerInfoColumn.implicitHeight + 24
        Layout.minimumHeight: 120
        color: host.cardBg
        radius: host.cardRadius
        border.color: host.cardBorder
        border.width: 1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            Text {
                text: "Joueurs (UDP)"
                color: host.textPrimary
                font.pixelSize: 15
                font.bold: true
            }
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                ListView {
                    id: playersListView
                    model: Catway.players
                    spacing: 4
                    delegate: Rectangle {
                        width: playersListView.width - 4
                        height: 40
                        color: panelRoot.selectedPlayer === modelData ? host.accent + "40" : "#222226"
                        radius: 6
                        border.color: panelRoot.selectedPlayer === modelData ? host.accent : "transparent"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8
                            Text {
                                text: modelData ? (modelData.nickname + " · " + modelData.playerId) : "?"
                                color: host.textPrimary
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: (modelData && (modelData.ip || modelData.port)) ? (modelData.ip + ":" + modelData.port) : "—"
                                color: host.textSecondary
                                font.pixelSize: 11
                                font.family: "Consolas"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton
                            onClicked: panelRoot.playerClicked(modelData)
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: playerInfoColumn.implicitHeight + 24
        visible: !!selectedPlayer
        color: host.cardBg
        radius: host.cardRadius
        border.color: host.cardBorder
        border.width: 1

        ColumnLayout {
            id: playerInfoColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8
            Text {
                text: "Joueur sélectionné"
                color: host.textPrimary
                font.pixelSize: 15
                font.bold: true
            }
            GridLayout {
                columns: 2
                rowSpacing: 4
                columnSpacing: 12
                Layout.fillWidth: true
                Text { text: "ID"; color: host.textSecondary; font.pixelSize: 11 }
                Text {
                    text: selectedPlayer ? selectedPlayer.playerId : "—"
                    color: host.textPrimary
                    font.pixelSize: 12
                    font.family: "Consolas"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
                Text { text: "Nickname"; color: host.textSecondary; font.pixelSize: 11 }
                Text {
                    text: selectedPlayer ? selectedPlayer.nickname : "—"
                    color: host.textPrimary
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text { text: "IP:Port"; color: host.textSecondary; font.pixelSize: 11 }
                Text {
                    text: selectedPlayer && (selectedPlayer.ip || selectedPlayer.port)
                          ? (selectedPlayer.ip + ":" + selectedPlayer.port) : "—"
                    color: host.textPrimary
                    font.pixelSize: 12
                    font.family: "Consolas"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
                Text { text: "Socket"; color: host.textSecondary; font.pixelSize: 11 }
                Text {
                    text: (selectedPlayer && selectedPlayer.socketInfo)
                          ? (selectedPlayer.socketInfo.publicAddress + ":" + selectedPlayer.socketInfo.publicPort) : "—"
                    color: host.textSecondary
                    font.pixelSize: 11
                    font.family: "Consolas"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Button {
                    text: " ✊ "
                    font.pixelSize: 18
                    implicitHeight: 40
                    implicitWidth: 48
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(host.accent, 1.2) : (parent.hovered ? host.accentHover : host.accent)
                        radius: 8
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: { /* TODO: action poing UDP vers selectedPlayer */ }
                }
                Button {
                    text: " 📤 "
                    font.pixelSize: 18
                    implicitHeight: 40
                    implicitWidth: 48
                    background: Rectangle {
                        color: parent.pressed ? "#2d2d35" : "transparent"
                        radius: 8
                        border.color: host.cardBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: host.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: { /* TODO: envoi UDP vers selectedPlayer */ }
                }
                Button {
                    text: " 🔄 "
                    font.pixelSize: 18
                    implicitHeight: 40
                    implicitWidth: 48
                    background: Rectangle {
                        color: parent.pressed ? "#2d2d35" : "transparent"
                        radius: 8
                        border.color: host.cardBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: host.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: { /* TODO: sync UDP avec selectedPlayer */ }
                }
                Item { Layout.fillWidth: true }
            }
        }
    }
}
