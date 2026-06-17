import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0
import theme

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
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingM

        Text {
            text: "Ports locaux"
            color: host.textPrimary
            font.pixelSize: Theme.fontSizeMedium
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
                spacing: Theme.spacingXS
                delegate: Rectangle {
                    width: localPortsList.width - 4
                    height: 38
                    color: host.selectedPortIndex === index ? Qt.lighter(host.accent, 1.8) : (mouse.containsMouse ? Theme.surfaceHover : Theme.surfaceAlt)
                    radius: Theme.radiusM
                    border.color: host.selectedPortIndex === index ? host.accent : "transparent"
                    border.width: 2

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingM
                        Text {
                            text: modelData ? modelData.publicAddress + ":" + modelData.publicPort : "?"
                            color: host.selectedPortIndex === index ? "#1e1e22" : host.textPrimary
                            font.pixelSize: Theme.fontSizeBody
                            font.family: "Consolas"
                        }
                        Text {
                            text: "·"
                            color: host.selectedPortIndex === index ? "#3f3f46" : host.textSecondary
                            font.pixelSize: Theme.fontSizeBody
                        }
                        Text {
                            text: modelData ? modelData.localPort : "?"
                            color: host.selectedPortIndex === index ? "#3f3f46" : host.textSecondary
                            font.pixelSize: Theme.fontSizeSmall
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
