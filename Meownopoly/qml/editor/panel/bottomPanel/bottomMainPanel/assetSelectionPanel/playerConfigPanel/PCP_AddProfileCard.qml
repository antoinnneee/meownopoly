import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
 * Card "+ Ajouter une classe" — toujours en queue de PCP_ProfileRow.
 * Mêmes dimensions qu'une PCP_ProfileCard (largeur min 3 cm, ratio 1:1.6).
 */
Rectangle {
    id: root

    signal addRequested()

    readonly property real _minW: Screen.pixelDensity * 30
    readonly property real _ratio: 1.6

    implicitWidth: Math.max(_minW, height / _ratio)
    color: hover.hovered ? "#2f2f2f" : "#252525"
    border.color: hover.hovered ? "#FFC107" : "#3a3a3a"
    border.width: 2
    radius: 6
    clip: true

    HoverHandler { id: hover }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Screen.pixelDensity * 1.5

        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "+"
            color: "#FFC107"
            font.pixelSize: Math.round(Screen.pixelDensity * 12)
            font.bold: true
        }
        Label {
            Layout.alignment: Qt.AlignHCenter
            text: "Ajouter une classe"
            color: "#bbbbbb"
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.addRequested()
    }
}
