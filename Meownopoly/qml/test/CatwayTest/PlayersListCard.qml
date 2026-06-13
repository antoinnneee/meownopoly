import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0
import theme

Rectangle {
    id: playersListCard
    required property var host

    signal playerClicked(var player)

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 100
    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingM

        Text {
            text: "Joueurs"
            color: host.textPrimary
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 0
            Layout.bottomMargin: Theme.spacingXS
            Text {
                text: "ID / Nickname"
                color: host.textSecondary
                font.pixelSize: Theme.fontSizeCaption
                font.capitalization: Font.AllUppercase
                Layout.preferredWidth: 120
                elide: Text.ElideRight
            }
            Rectangle { width: 1; height: 12; color: host.cardBorder; Layout.alignment: Qt.AlignVCenter }
            Text {
                text: "IP:Port (dest.)"
                color: host.textSecondary
                font.pixelSize: Theme.fontSizeCaption
                font.capitalization: Font.AllUppercase
                Layout.preferredWidth: 110
                elide: Text.ElideRight
            }
            Rectangle { width: 1; height: 12; color: host.cardBorder; Layout.alignment: Qt.AlignVCenter }
            Text {
                text: "SocketInfo"
                color: host.textSecondary
                font.pixelSize: Theme.fontSizeCaption
                font.capitalization: Font.AllUppercase
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ListView {
                id: playersList
                model: Catway.players
                spacing: Theme.spacingXS
                delegate: Rectangle {
                    width: playersList.width - 4
                    height: 48
                    color: rowMouseArea.pressed ? host.cardBorder : Theme.surfaceAlt
                    radius: Theme.radiusM
                    clip: true

                    MouseArea {
                        id: rowMouseArea
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: playersListCard.playerClicked(modelData)
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: 0
                        ColumnLayout {
                            spacing: Theme.spacingXXS
                            Layout.preferredWidth: 120
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                text: modelData ? modelData.nickname : "?"
                                color: host.textPrimary
                                font.pixelSize: Theme.fontSizeBody
                                font.bold: true
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }
                            Text {
                                text: modelData ? modelData.playerId : "?"
                                color: host.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: "Consolas"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }
                        }
                        Rectangle { width: 1; height: 28; color: host.cardBorder; Layout.alignment: Qt.AlignVCenter }
                        ColumnLayout {
                            spacing: Theme.spacingXXS
                            Layout.preferredWidth: 110
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                text: (modelData && (modelData.ip || modelData.port)) ? (modelData.ip + (modelData.port ? (":" + modelData.port) : "")) : "—"
                                color: host.textSecondary
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: "Consolas"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }
                        }
                        Rectangle { width: 1; height: 28; color: host.cardBorder; Layout.alignment: Qt.AlignVCenter }
                        ColumnLayout {
                            spacing: 0
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                text: (modelData && modelData.socketInfo) ? (modelData.socketInfo.publicAddress + ":" + modelData.socketInfo.publicPort) : "—"
                                color: Theme.textMuted
                                font.pixelSize: Theme.fontSizeSmall
                                font.family: "Consolas"
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                Layout.fillWidth: true
                            }
                        }
                        Button {
                            text: "Retirer"
                            flat: true
                            font.pixelSize: Theme.fontSizeBody
                            implicitHeight: 32
                            Layout.preferredWidth: 72
                            Layout.alignment: Qt.AlignVCenter
                            contentItem: Text { text: parent.text; color: Theme.dangerSoft; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle {
                                color: parent.pressed ? "#3f1d1d" : "transparent"
                                radius: Theme.radiusM
                            }
                            onClicked: Catway.removePlayer(modelData)
                        }
                    }
                }
            }
        }
    }
}
