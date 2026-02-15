import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0

Rectangle {
    id: root
    color: "#16161a"
    signal backRequested()

    property UdpSocketInfo selectedSocketInfo: null
    property int selectedPortIndex: -1

    property color cardBg: "#1c1c21"
    property color cardBorder: "#2d2d35"
    property color accent: "#7c3aed"
    property color accentHover: "#8b5cf6"
    property color textPrimary: "#f4f4f5"
    property color textSecondary: "#a1a1aa"
    property int cardRadius: 12

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: 16
            Button {
                text: "← Retour"
                font.pixelSize: 14
                implicitHeight: 40
                background: Rectangle {
                    color: parent.pressed ? "#2d2d35" : "transparent"
                    radius: 8
                    border.color: root.cardBorder
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: root.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: root.backRequested()
            }
            TabBar {
                id: tabBar
                Layout.alignment: Qt.AlignLeft
                currentIndex: stack.currentIndex
                onCurrentIndexChanged: stack.currentIndex = currentIndex
                background: Rectangle { color: "transparent" }
                TabButton {
                    text: "Catway"
                    font.pixelSize: 14
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: 8
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
                TabButton {
                    text: "UDP Tests"
                    font.pixelSize: 14
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: 8
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
            }
            Text {
                text: "Test Catway"
                color: root.textPrimary
                font.pixelSize: 22
                font.bold: true
                font.letterSpacing: 0.5
                Layout.fillWidth: true
            }
        }

        StackLayout {
            id: stack
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: tabBar.currentIndex

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                contentWidth: availableWidth
                contentHeight: contentColumn.implicitHeight
                ColumnLayout {
                    id: contentColumn
                    width: root.width - 32
                    spacing: 16
                    RowLayout {
                    spacing: 16
                    Layout.fillWidth: true
                    Layout.minimumHeight: 800

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 280
                        spacing: 12

                        StunCard { Layout.fillWidth: true; host: root }

                        LocalPortsCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            host: root
                            onPortClicked: function(socketInfo, index) {
                                root.selectedPortIndex = index
                                root.selectedSocketInfo = socketInfo
                            }
                        }
                    }


                    ColumnLayout {
                        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                        Layout.fillWidth: true
                        Layout.minimumWidth: 280
                        spacing: 12

                        ChatClientCard {
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                            Layout.fillWidth: true
                            host: root
                            onParticipantClicked: function(playerId, nickname) {
                                createPlayerForm.setPlayer(playerId, nickname)
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 280
                        spacing: 12

                        CreatePlayerForm {
                            id: createPlayerForm
                            Layout.fillWidth: true
                            host: root
                            playerComponent: playerComponent
                        }

                        PlayersListCard {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            host: root
                            onPlayerClicked: function(player) {
                                createPlayerForm.loadPlayer(player)
                            }
                        }
                    }
                }
            }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                contentWidth: availableWidth
                contentHeight: udpTestContent.implicitHeight
                ColumnLayout {
                    id: udpTestContent
                    width: root.width - 32
                    spacing: 12
                    UdpTestTab {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 700
                        host: root
                    }
                }
            }
        }
    }

    Component {
        id: playerComponent
        PlayerNetwork {}
    }
}
