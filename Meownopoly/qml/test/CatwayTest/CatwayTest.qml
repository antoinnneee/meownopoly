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
            Text {
                text: "Test Catway"
                color: root.textPrimary
                font.pixelSize: 22
                font.bold: true
                font.letterSpacing: 0.5
                Layout.fillWidth: true
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16

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
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 280
                spacing: 12

                CreatePlayerForm {
                Layout.fillWidth: true
                    host: root
                    playerComponent: playerComponent
                }

                PlayersListCard {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    host: root
                }
            }
        }
    }

    Component {
        id: playerComponent
        PlayerNetwork {}
    }
}
