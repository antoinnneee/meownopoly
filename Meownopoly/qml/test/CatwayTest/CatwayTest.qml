import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0
import theme

Rectangle {
    id: root
    color: Theme.background
    signal backRequested()

    property UdpSocketInfo selectedSocketInfo: null
    property int selectedPortIndex: -1

    property color cardBg: Theme.surface
    property color cardBorder: Theme.border
    property color accent: "#7c3aed"
    property color accentHover: "#8b5cf6"
    property color textPrimary: Theme.textPrimary
    property color textSecondary: Theme.textHint
    property int cardRadius: Theme.radiusXXL

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingXL

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            spacing: Theme.spacingXXL
            Button {
                text: "← Retour"
                font.pixelSize: Theme.fontSizeMedium
                implicitHeight: 40
                background: Rectangle {
                    color: parent.pressed ? Theme.surfaceAlt : "transparent"
                    radius: Theme.radiusL
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
                    font.pixelSize: Theme.fontSizeMedium
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: Theme.radiusL
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
                TabButton {
                    text: "UDP Tests"
                    font.pixelSize: Theme.fontSizeMedium
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: Theme.radiusL
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
                TabButton {
                    text: "Game Network"
                    font.pixelSize: Theme.fontSizeMedium
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: Theme.radiusL
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
                TabButton {
                    text: "Editor Network"
                    font.pixelSize: Theme.fontSizeMedium
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: Theme.radiusL
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
                TabButton {
                    text: "Physics"
                    font.pixelSize: Theme.fontSizeMedium
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: Theme.radiusL
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
                TabButton {
                    text: "Painter"
                    font.pixelSize: Theme.fontSizeMedium
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: Theme.radiusL
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
                TabButton {
                    text: "V3 IA"
                    font.pixelSize: Theme.fontSizeMedium
                    contentItem: Text {
                        text: parent.text
                        color: parent.checked ? root.accent : root.textSecondary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle {
                        color: parent.checked ? root.cardBg : "transparent"
                        radius: Theme.radiusL
                        border.color: parent.checked ? root.accent : root.cardBorder
                        border.width: 1
                    }
                }
            }
            Text {
                text: "Test Catway"
                color: root.textPrimary
                font.pixelSize: Theme.fontSizeHeading
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
                    spacing: Theme.spacingXXL
                    SplitView {
                        id: columnSplitView
                        Layout.fillWidth: true
                        Layout.minimumHeight: 800
                        orientation: Qt.Horizontal
                        handle: Rectangle {
                            implicitWidth: 8
                            color: "transparent"
                            Rectangle {
                                width: 2
                                height: parent.height
                                anchors.centerIn: parent
                                color: root.cardBorder
                                radius: 1
                            }
                        }

                        Item {
                            SplitView.minimumWidth: 150
                            SplitView.preferredWidth: columnSplitView.width * 0.20
                            SplitView.fillWidth: true
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.spacingXL
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
                        }

                        Item {
                            SplitView.minimumWidth: 200
                            SplitView.preferredWidth: columnSplitView.width * 0.30
                            SplitView.fillWidth: true
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.spacingXL
                                ChatClientCard {
                                    Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                                    Layout.fillWidth: true
                                    host: root
                                    onParticipantClicked: function(playerId, nickname) {
                                        createPlayerForm.setPlayer(playerId, nickname)
                                    }
                                }
                            }
                        }

                        Item {
                            SplitView.minimumWidth: 180
                            SplitView.preferredWidth: columnSplitView.width * 0.50
                            SplitView.fillWidth: true
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: Theme.spacingXL
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
                    spacing: Theme.spacingXL
                    UdpTestTab {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 700
                        host: root
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
                contentHeight: gameNetworkContent.implicitHeight
                ColumnLayout {
                    id: gameNetworkContent
                    width: root.width - 32
                    spacing: Theme.spacingXL
                    GameNetworkTestTab {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 700
                        host: root
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
                contentHeight: editorNetworkContent.implicitHeight
                ColumnLayout {
                    id: editorNetworkContent
                    width: root.width - 32
                    spacing: Theme.spacingXL
                    EditorNetworkTestTab {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 700
                        host: root
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
                contentHeight: physicsContent.implicitHeight
                ColumnLayout {
                    id: physicsContent
                    width: root.width - 32
                    spacing: Theme.spacingXL
                    PhysicsTestTab {
                        Layout.fillWidth: true
                        Layout.minimumHeight: 600
                        host: root
                    }
                }
            }

            // Onglet Painter : test isolé du composant ZoneCanvasPainter
            // (rendu GPU 2D via QtCanvasPainter, Qt 6.11+).
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ZoneCanvasPainterTest {
                    anchors.fill: parent
                    anchors.margins: Theme.spacingXL
                }
            }

            // Onglet V3 IA : harness interactif des briques V3 (phases 0-5).
            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                contentWidth: availableWidth
                contentHeight: v3Content.implicitHeight
                ColumnLayout {
                    id: v3Content
                    width: root.width - 32
                    spacing: Theme.spacingXL
                    V3TestTab {
                        Layout.fillWidth: true
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
