import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Chat 1.0
import theme

Rectangle {
    id: root

    property var chatClient
    property string currentSessionId: ""
    property string _selectedName: ""

    signal sessionJoinRequested(string sessionId, string sessionName)

    implicitHeight: 22
    implicitWidth: selectorRow.implicitWidth + 10
    Layout.maximumWidth: 90

    color: selectorArea.containsMouse ? Theme.surfaceHover : "transparent"
    radius: Theme.radiusS
    border.color: selectorArea.containsMouse ? Theme.borderLight : "transparent"
    border.width: 1

    Behavior on color { ColorAnimation { duration: Theme.durationFast } }

    RowLayout {
        id: selectorRow
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingXS
        anchors.rightMargin: Theme.spacingXS
        spacing: Theme.spacingXXS

        Text {
            text: root._selectedName !== "" ? root._selectedName : (root.currentSessionId !== "" ? root.currentSessionId : "—")
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: "▾"
            color: sessionPopup.visible ? Theme.accent : Theme.textDisabled
            font.pixelSize: Theme.fontSizeTiny
        }
    }

    MouseArea {
        id: selectorArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            ChatSessionManager.requestSessionsRefresh()
            sessionPopup.visible ? sessionPopup.close() : sessionPopup.open()
        }
    }

    ToolTip {
        visible: selectorArea.containsMouse && !sessionPopup.visible
        text: root._selectedName !== ""
            ? root._selectedName
            : (root.currentSessionId !== "" ? root.currentSessionId : "—")
        delay: 600
    }

    Popup {
        id: sessionPopup
        y: root.height + 4
        x: root.width - width
        width: 230
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surface
            border.color: Theme.border
            border.width: 1
            radius: Theme.radiusM

            // Ombre portée légère
            layer.enabled: true
            layer.effect: null
        }

        contentItem: Column {
            spacing: 0

            // En-tête du popup
            Item {
                width: 230
                height: 28

                Text {
                    anchors.centerIn: parent
                    text: "Sessions disponibles"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeTiny
                    font.bold: true
                    font.letterSpacing: 0.5
                }
            }

            Rectangle { width: 230; height: 1; color: Theme.surfaceHover }

            // Liste des sessions
            ListView {
                id: sessionList
                width: 230
                height: Math.min(contentHeight, 200)
                model: ChatSessionManager.availableSessions
                clip: true
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: 230
                    height: 48
                    color: delegateHover.containsMouse ? Theme.surfaceHover : "transparent"

                    Behavior on color { ColorAnimation { duration: 80 } }

                    // Highlight session courante
                    Rectangle {
                        visible: modelData.sessionId === root.currentSessionId
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: Theme.accent
                        radius: 1
                    }

                    Column {
                        anchors {
                            left: parent.left; leftMargin: Theme.spacingXL
                            right: parent.right; rightMargin: Theme.spacingM
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: Theme.spacingXXS

                        Text {
                            text: modelData.name ?? modelData.sessionId
                            color: modelData.sessionId === root.currentSessionId ? Theme.accent : Theme.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: "🎮 " + (modelData.hostNickname ?? "?") +
                                  "  ·  👥 " + (modelData.players ?? 0) +
                                  "/" + (modelData.maxPlayers ?? "∞")
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontSizeTiny
                        }
                    }

                    MouseArea {
                        id: delegateHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            sessionPopup.close()
                            root._selectedName = modelData.name ?? modelData.sessionId
                            root.sessionJoinRequested(modelData.sessionId, modelData.name ?? "")
                        }
                    }

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 1
                        color: Theme.surfaceAlt
                        visible: index < sessionList.count - 1
                    }
                }

                // Placeholder
                Text {
                    anchors.centerIn: parent
                    text: "Aucune session\ndisponible"
                    horizontalAlignment: Text.AlignHCenter
                    color: Theme.textDisabled
                    font.pixelSize: Theme.fontSizeTiny
                    lineHeight: 1.4
                    visible: sessionList.count === 0
                }
            }
        }
    }
}
