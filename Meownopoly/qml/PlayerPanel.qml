import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
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

            delegate: Rectangle {
                width: parent.width
                height: 100
                color: "#2c3e50"
                radius: 8

                RowLayout {
                    anchors {
                        fill: parent
                        margins: 10
                    }
                    spacing: 10

                    Rectangle {
                        width: 40
                        height: 40
                        radius: 20
                        color: modelData && modelData.color ? modelData.color : "#7f8c8d"
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            text: modelData && modelData.name ? modelData.name : "Unknown Player"
                            color: "white"
                            font.bold: true
                            font.pixelSize: 16
                        }

                        Text {
                            text: "Kibble: " + (modelData && modelData.kibble ? modelData.kibble : 0)
                            color: "#bdc3c7"
                        }

                        Text {
                            text: "Properties: " + (modelData && modelData.propertyCount ? modelData.propertyCount : 0)
                            color: "#bdc3c7"
                        }
                    }

                    Rectangle {
                        width: 10
                        height: 10
                        radius: 5
                        color: "#27ae60"
                        visible: index === 0
                    }
                }
            }
        }
    }
} 