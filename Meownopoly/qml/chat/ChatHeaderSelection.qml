import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Meownopoly.Chat 1.0

Rectangle {
    id: root

    property var chatClient
    property string currentSessionId: ""
    property string _selectedName: ""

    signal sessionJoinRequested(string sessionId, string sessionName)

    implicitHeight: 22
    implicitWidth: selectorRow.implicitWidth + 10
    Layout.maximumWidth: 90

    color: selectorArea.containsMouse ? "#3a3a3a" : "transparent"
    radius: 4
    border.color: selectorArea.containsMouse ? "#555555" : "transparent"
    border.width: 1

    Behavior on color { ColorAnimation { duration: 100 } }

    RowLayout {
        id: selectorRow
        anchors.fill: parent
        anchors.leftMargin: 4
        anchors.rightMargin: 4
        spacing: 2

        Text {
            text: root._selectedName !== "" ? root._selectedName : (root.currentSessionId !== "" ? root.currentSessionId : "—")
            color: "#888888"
            font.pointSize: 8
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Text {
            text: "▾"
            color: sessionPopup.visible ? "#4A90E2" : "#666666"
            font.pointSize: 7
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
            color: "#2a2a2a"
            border.color: "#444444"
            border.width: 1
            radius: 6

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
                    color: "#888888"
                    font.pointSize: 7
                    font.bold: true
                    font.letterSpacing: 0.5
                }
            }

            Rectangle { width: 230; height: 1; color: "#3a3a3a" }

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
                    color: delegateHover.containsMouse ? "#363636" : "transparent"

                    Behavior on color { ColorAnimation { duration: 80 } }

                    // Highlight session courante
                    Rectangle {
                        visible: modelData.sessionId === root.currentSessionId
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 3
                        color: "#4A90E2"
                        radius: 1
                    }

                    Column {
                        anchors {
                            left: parent.left; leftMargin: 12
                            right: parent.right; rightMargin: 8
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 3

                        Text {
                            text: modelData.name ?? modelData.sessionId
                            color: modelData.sessionId === root.currentSessionId ? "#4A90E2" : "#cccccc"
                            font.pointSize: 8
                            font.bold: true
                            elide: Text.ElideRight
                            width: parent.width
                        }

                        Text {
                            text: "🎮 " + (modelData.hostNickname ?? "?") +
                                  "  ·  👥 " + (modelData.players ?? 0) +
                                  "/" + (modelData.maxPlayers ?? "∞")
                            color: "#666666"
                            font.pointSize: 7
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
                        color: "#333333"
                        visible: index < sessionList.count - 1
                    }
                }

                // Placeholder
                Text {
                    anchors.centerIn: parent
                    text: "Aucune session\ndisponible"
                    horizontalAlignment: Text.AlignHCenter
                    color: "#555555"
                    font.pointSize: 7
                    lineHeight: 1.4
                    visible: sessionList.count === 0
                }
            }
        }
    }
}
