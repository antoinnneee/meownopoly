import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0

Rectangle {
    required property var host

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 120
    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    signal portClicked(var socketInfo, int index)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "Ports locaux"
            color: host.textPrimary
            font.pixelSize: 15
            font.bold: true
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            ListView {
                id: localPortsList
                model: Catway.localPorts
                spacing: 4
                delegate: Rectangle {
                    width: localPortsList.width - 4
                    height: 38
                    color: host.selectedPortIndex === index ? Qt.lighter(host.accent, 1.8) : (mouse.containsMouse ? "#25252a" : "#222226")
                    radius: 6
                    border.color: host.selectedPortIndex === index ? host.accent : "transparent"
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 8
                        Text {
                            text: modelData ? modelData.publicAddress + ":" + modelData.publicPort : "?"
                            color: host.selectedPortIndex === index ? "#1e1e22" : host.textPrimary
                            font.pixelSize: 12
                            font.family: "Consolas"
                        }
                        Text {
                            text: "·"
                            color: host.selectedPortIndex === index ? "#3f3f46" : host.textSecondary
                            font.pixelSize: 12
                        }
                        Text {
                            text: modelData ? modelData.localPort : "?"
                            color: host.selectedPortIndex === index ? "#3f3f46" : host.textSecondary
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: portClicked(modelData, index)
                    }
                }
            }
        }
    }
}
