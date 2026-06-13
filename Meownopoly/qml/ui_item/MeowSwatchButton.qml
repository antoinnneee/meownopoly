import QtQuick
import theme

/*
 * MeowSwatchButton — petit bouton-pastille coloré des pickers (presets couleur…).
 *
 * Extrait du component SwatchButton de VEP_ColorEffectsSection. Carré coloré
 * cliquable avec un glyphe central (ex: "+", "×"). `baseColor`/`pressedColor`
 * sont laissés libres (couleurs de donnée, pas thémées). `hovered` exposé pour
 * brancher un ToolTip côté appelant.
 */
Rectangle {
    id: swatchRoot

    property color baseColor: Theme.pressed(Theme.accentAlt)
    property color pressedColor: Theme.accentAlt
    property string text: ""
    signal clicked()
    readonly property alias hovered: swatchMouse.containsMouse

    implicitWidth: 24
    implicitHeight: 22
    radius: Theme.radiusXS
    color: swatchRoot.enabled ? (swatchMouse.pressed ? swatchRoot.pressedColor : swatchRoot.baseColor) : Theme.border
    opacity: swatchRoot.enabled ? 1.0 : 0.55

    Text {
        anchors.centerIn: parent
        text: swatchRoot.text
        color: swatchRoot.enabled ? "#ffffff" : Theme.textMuted
        font.pixelSize: Theme.fontSizeMedium
        font.bold: true
    }

    MouseArea {
        id: swatchMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: swatchRoot.clicked()
    }
}
