import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0
import theme

ColumnLayout {
    id: panelRoot
    required property var host
    property var selectedPlayer: null

    signal playerClicked(var player)

    spacing: Theme.spacingXL

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
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingM
            Text {
                text: "Joueurs (UDP)"
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeMedium
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
                    spacing: Theme.spacingXS
                    delegate: Rectangle {
                        width: playersListView.width - 4
                        height: 40
                        color: panelRoot.selectedPlayer === modelData ? host.accent + "40" : Theme.surfaceAlt
                        radius: Theme.radiusM
                        border.color: panelRoot.selectedPlayer === modelData ? host.accent : "transparent"
                        border.width: 1
                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: Theme.spacingM
                            spacing: Theme.spacingM
                            Text {
                                text: modelData ? (modelData.nickname + " · " + modelData.playerId) : "?"
                                color: host.textPrimary
                                font.pixelSize: Theme.fontSizeBody
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: (modelData && (modelData.ip || modelData.port)) ? (modelData.ip + ":" + modelData.port) : "—"
                                color: host.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
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
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingM
            Text {
                text: "Joueur sélectionné"
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
            }
            GridLayout {
                columns: 2
                rowSpacing: Theme.spacingXS
                columnSpacing: Theme.spacingXL
                Layout.fillWidth: true
                Text { text: "ID"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
                Text {
                    text: selectedPlayer ? selectedPlayer.playerId : "—"
                    color: host.textPrimary
                    font.pixelSize: Theme.fontSizeBody
                    font.family: "Consolas"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
                Text { text: "Nickname"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
                Text {
                    text: selectedPlayer ? selectedPlayer.nickname : "—"
                    color: host.textPrimary
                    font.pixelSize: Theme.fontSizeBody
                    Layout.fillWidth: true
                    elide: Text.ElideRight
                }
                Text { text: "IP:Port"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
                Text {
                    text: selectedPlayer && (selectedPlayer.ip || selectedPlayer.port)
                          ? (selectedPlayer.ip + ":" + selectedPlayer.port) : "—"
                    color: host.textPrimary
                    font.pixelSize: Theme.fontSizeBody
                    font.family: "Consolas"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
                Text { text: "Socket"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
                Text {
                    text: (selectedPlayer && selectedPlayer.socketInfo)
                          ? (selectedPlayer.socketInfo.publicAddress + ":" + selectedPlayer.socketInfo.publicPort) : "—"
                    color: host.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.family: "Consolas"
                    Layout.fillWidth: true
                    elide: Text.ElideMiddle
                }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM
                Button {
                    id: holePunchButton
                    text: " ✊ "
                    font.pixelSize: Theme.fontSizeTitle
                    implicitHeight: 40
                    implicitWidth: 48
                    background: Rectangle {
                        color: parent.pressed ? Qt.darker(host.accent, 1.2) : (parent.hovered ? host.accentHover : host.accent)
                        radius: Theme.radiusL
                    }
                    contentItem: Text {
                        text: parent.text
                        color: Theme.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (selectedPlayer) {
                            Catway.initiateHolePunch(selectedPlayer)
                        }
                    }
                }
                Button {
                    text: " 📤 "
                    font.pixelSize: Theme.fontSizeTitle
                    implicitHeight: 40
                    implicitWidth: 48
                    background: Rectangle {
                        color: parent.pressed ? Theme.surfaceAlt : "transparent"
                        radius: Theme.radiusL
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
                    font.pixelSize: Theme.fontSizeTitle
                    implicitHeight: 40
                    implicitWidth: 48
                    background: Rectangle {
                        color: parent.pressed ? Theme.surfaceAlt : "transparent"
                        radius: Theme.radiusL
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
