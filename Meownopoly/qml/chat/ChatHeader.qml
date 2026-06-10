import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Chat 1.0
import theme

Rectangle {
    id: headerBar
    Layout.fillWidth: true
    Layout.preferredHeight: 50
    color: Theme.surfaceAlt
    border.color: Theme.border
    border.width: 1

    property var chatClient
    property var drawer

    signal toggleParticipantsPanel()
    signal sessionJoinRequested(string sessionId, string sessionName)

    // Zone de redimensionnement sur le bord gauche
    Rectangle {
        id: resizeHandle
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 8
        color: resizeMouseArea.pressed ? Theme.accent : (resizeMouseArea.containsMouse ? Theme.border : "transparent")
        z: 15

        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: parent.height * 0.4
            color: resizeMouseArea.containsMouse || (drawer && drawer.isResizing) ? Theme.accent : Theme.textDisabled
            radius: 1
        }

        MouseArea {
            id: resizeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeHorCursor
            preventStealing: true

            property real startX: 0
            property real startWidth: 0
            property int minWidth: 280
            property int maxWidth: 600

            onPressed: function(mouse) {
                if (drawer) drawer.isResizing = true
                startX = mapToGlobal(mouse.x, mouse.y).x
                startWidth = drawer ? drawer.width : 340
            }

            onPositionChanged: function(mouse) {
                if (pressed && drawer) {
                    var globalX = mapToGlobal(mouse.x, mouse.y).x
                    var delta = startX - globalX
                    var newWidth = Math.max(minWidth, Math.min(maxWidth, startWidth + delta))
                    drawer.width = newWidth
                }
            }

            onReleased: {
                if (drawer) drawer.isResizing = false
            }
        }

        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingXXL
        anchors.rightMargin: Theme.spacingXL
        spacing: Theme.spacingM

        Text {
            text: "💬"
            font.pixelSize: Theme.fontSizeHeading
        }

        Text {
            text: "Chat"
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeBody
            font.bold: true
            Layout.fillWidth: true
        }

        // Participants badge
        Rectangle {
            Layout.preferredHeight: 24
            Layout.preferredWidth: participantsBadgeRow.implicitWidth + 16
            color: participantsBtnArea.containsMouse ? Theme.hover(Theme.surfaceHover) : Theme.surfaceHover
            radius: 12
            border.color: participantsBtnArea.containsMouse ? Theme.accent : Theme.borderLight
            border.width: 1
            visible: chatClient ? chatClient.connected : false

            Behavior on color { ColorAnimation { duration: Theme.durationFast } }
            Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }

            RowLayout {
                id: participantsBadgeRow
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Text {
                    text: "👥"
                    font.pixelSize: Theme.fontSizeSmall
                }

                Text {
                    text: chatClient ? chatClient.participantCount : "0"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }

            MouseArea {
                id: participantsBtnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: headerBar.toggleParticipantsPanel()
            }

            ToolTip {
                visible: participantsBtnArea.containsMouse
                text: "Participants connectés"
                delay: 600
            }
        }

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            color: clearBtnArea.containsMouse ? Theme.border : "transparent"
            radius: Theme.radiusS
            visible: chatClient ? chatClient.connected : false

            Text {
                text: "🗑️"
                font.pixelSize: Theme.fontSizeBody
                anchors.centerIn: parent
            }

            MouseArea {
                id: clearBtnArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    if (chatClient) chatClient.clearHistory()
                }
            }
        }

        Rectangle {
            Layout.preferredWidth: 10
            Layout.preferredHeight: 10
            radius: 5
            color: chatClient && chatClient.connected ? "#4a8a4a" : "#aa4444"
            border.color: chatClient && chatClient.connected ? Theme.accentAlt : "#cc4444"
            border.width: 1

            SequentialAnimation on opacity {
                running: chatClient ? !chatClient.connected : false
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 800 }
                NumberAnimation { to: 1.0; duration: 800 }
            }
        }
        ChatHeaderSelection {
            chatClient: headerBar.chatClient
            currentSessionId: headerBar.chatClient ? ChatSessionManager.sessionNameForId(headerBar.chatClient.sessionId) : ""
            onSessionJoinRequested: function(sessionId, sessionName) {
                headerBar.sessionJoinRequested(sessionId, sessionName)
            }
        }
    }
}
