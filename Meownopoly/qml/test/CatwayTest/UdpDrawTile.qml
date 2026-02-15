import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: udpDrawTileRoot
    required property var host
    property int selectedColorIndex: 0

    Layout.fillWidth: true
    Layout.preferredHeight: 260
    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Dessin (16×64)"
                color: host.textPrimary
                font.pixelSize: 15
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Button {
                text: "Effacer"
                implicitHeight: 28
                font.pixelSize: 11
                background: Rectangle {
                    color: parent.pressed ? "#2d2d35" : "transparent"
                    radius: 4
                    border.color: host.cardBorder
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: host.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: drawGrid.clearAll()
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                DrawGrid {
                    id: drawGrid
                    anchors.centerIn: parent
                    host: host
                }
            }
            ColumnLayout {
                Layout.alignment: Qt.AlignVCenter
                spacing: 6
                Text {
                    text: "Couleur"
                    color: host.textSecondary
                    font.pixelSize: 11
                    Layout.alignment: Qt.AlignHCenter
                }
                GridLayout {
                    columns: 2
                    rowSpacing: 4
                    columnSpacing: 4
                    Layout.alignment: Qt.AlignHCenter
                    Repeater {
                        id: colorRepeater
                        model: [
                            "#7c3aed",
                            "#ef4444",
                            "#22c55e",
                            "#3b82f6",
                            "#eab308",
                            "#f97316",
                            "#ec4899",
                            "#f4f4f5"
                        ]
                        delegate: Rectangle {
                            width: 28
                            height: 28
                            radius: 6
                            color: modelData
                            border.width: index === udpDrawTileRoot.selectedColorIndex ? 2 : 0
                            border.color: host.textPrimary
                            Layout.row: Math.floor(index / 2)
                            Layout.column: index % 2
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                onClicked: {
                                    udpDrawTileRoot.selectedColorIndex = index
                                    drawGrid.paintColor = modelData
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
