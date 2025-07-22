import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "./style"
import Game

Rectangle {
    id: root
    color: "#34495e"

    ColumnLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 15

        Text {
            text: "Players"
            color: "white"
            font.pixelSize: 24
            font.bold: true
            Layout.alignment: Qt.AlignHCenter
        }

        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            clip: true
            model: Game.players

            delegate: Item {
                width: parent.width
                height: 100

                // Background rectangle with pseudo-glow effect
                Rectangle {
                    id: backgroundGlow
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: 10
                    color: index === Game.currentPlayerIndex ? "#2980b9" : "transparent"
                    visible: index === Game.currentPlayerIndex
                    opacity: 0.5
                }

                Rectangle {
                    id: playerCard
                    anchors.fill: parent
                    color: index === Game.currentPlayerIndex ? "#3498db" : "#2c3e50"
                    radius: 8

                    // Smooth color transition
                    Behavior on color {
                        ColorAnimation { duration: 200 }
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 10

                        // Player token circle with current player indicator
                        Item {
                            width: 40
                            height: 40
                            Layout.alignment: Qt.AlignVCenter

                            Rectangle {
                                id: playerToken
                                anchors.fill: parent
                                radius: width / 2
                                color: modelData && modelData.color ? modelData.color : "#7f8c8d"
                                border.width: index === Game.currentPlayerIndex ? 3 : 0
                                border.color: "white"

                                // Player initial
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData && modelData.name ? modelData.name.charAt(0).toUpperCase() : "?"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: parent.width * 0.5
                                }
                            }

                            // Current player indicator
                            Rectangle {
                                visible: index === Game.currentPlayerIndex
                                width: 16
                                height: 16
                                radius: width / 2
                                color: "#2ecc71"
                                anchors {
                                    right: parent.right
                                    bottom: parent.bottom
                                }
                                border.width: 2
                                border.color: "white"

                                // Pulsing animation
                                SequentialAnimation on scale {
                                    running: index === Game.currentPlayerIndex
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.2; duration: 800; easing.type: Easing.InOutQuad }
                                    NumberAnimation { to: 1.0; duration: 800; easing.type: Easing.InOutQuad }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 5

                                Text {
                                    text: modelData && modelData.name ? modelData.name : "Unknown Player"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 16
                                }

                                Text {
                                    visible: index === Game.currentPlayerIndex
                                    text: "(Current Turn)"
                                    color: "#2ecc71"
                                    font.italic: true
                                    font.pixelSize: 12
                                }
                            }

                            Text {
                                text: "Kibble: " + (modelData && modelData.kibble ? modelData.kibble : 0) + "K"
                                color: "#bdc3c7"
                                font.pixelSize: 14
                            }

                            Text {
                                text: "Properties: " + (modelData && modelData.propertyCount ? modelData.propertyCount : 0)
                                color: "#bdc3c7"
                                font.pixelSize: 14
                            }

                            Text {
                                text: "Position: " + (modelData && modelData.position ? modelData.position : 0)
                                color: "#bdc3c7"
                                font.pixelSize: 14
                            }
                        }
                    }
                }
            }
        }
    }
} 