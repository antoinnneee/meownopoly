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
            font.pixelSize: 20
        }

        Text {
            text: "Chat"
            color: "#cccccc"
            font.pixelSize: 14
            font.bold: true
            Layout.fillWidth: true
        }

        Rectangle {
            Layout.preferredWidth: 24
            Layout.preferredHeight: 24
            color: clearBtnArea.containsMouse ? "#444444" : "transparent"
            radius: 4
            visible: chatClient && chatClient.connected

            Text {
                text: "🗑️"
                font.pixelSize: 14
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
                running: chatClient && !chatClient.connected
                loops: Animation.Infinite
                NumberAnimation { to: 0.4; duration: 800 }
                NumberAnimation { to: 1.0; duration: 800 }
            }
        }

        Text {
            text: drawer ? drawer.gameId : ""
            color: "#888888"
            font.pixelSize: 10
            elide: Text.ElideRight
            Layout.maximumWidth: 80
        }
    }
}
