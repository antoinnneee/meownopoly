import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: headerBar
    Layout.fillWidth: true
    Layout.preferredHeight: 50
    color: "#333333"
    border.color: "#444444"
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
        color: resizeMouseArea.pressed ? "#4A90E2" : (resizeMouseArea.containsMouse ? "#444444" : "transparent")
        z: 15

        Rectangle {
            anchors.centerIn: parent
            width: 2
            height: parent.height * 0.4
            color: resizeMouseArea.containsMouse || (drawer && drawer.isResizing) ? "#4A90E2" : "#666666"
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

        Behavior on color { ColorAnimation { duration: 150 } }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 12
        spacing: 8

        Text {
            text: "💬"
            font.pointSize: 15
        }

        Text {
            text: "Chat"
            color: "#cccccc"
            font.pointSize: 10
            font.bold: true
            Layout.fillWidth: true
        }

        // Participants badge
        Rectangle {
            Layout.preferredHeight: 24
            Layout.preferredWidth: participantsBadgeRow.implicitWidth + 16
            color: participantsBtnArea.containsMouse ? "#444444" : "#3a3a3a"
            radius: 12
            border.color: participantsBtnArea.containsMouse ? "#4A90E2" : "#555555"
            border.width: 1
            visible: chatClient ? chatClient.connected : false

            Behavior on color { ColorAnimation { duration: 100 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }

            RowLayout {
                id: participantsBadgeRow
                anchors.centerIn: parent
                spacing: 4

                Text {
                    text: "👥"
                    font.pointSize: 8
                }

                Text {
                    text: chatClient ? chatClient.participantCount : "0"
                    color: "#cccccc"
                    font.pointSize: 8
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
            color: clearBtnArea.containsMouse ? "#444444" : "transparent"
            radius: 4
            visible: chatClient ? chatClient.connected : false

            Text {
                text: "🗑️"
                font.pointSize: 10
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
            border.color: chatClient && chatClient.connected ? "#569c58" : "#cc4444"
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
            currentSessionId: drawer ? drawer.gameId : ""
            onSessionJoinRequested: function(sessionId, sessionName) {
                headerBar.sessionJoinRequested(sessionId, sessionName)
            }
        }
    }
}
