import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
 * InlineColorPicker.qml — Sélecteur de couleur HSL inline (édition live).
 *
 * 3 sliders à fond dégradé : teinte (arc-en-ciel), saturation, luminance.
 * Émet `colorPicked(color)` à chaque mouvement (pas de popup). La couleur
 * d'entrée est décomposée en HSL ; on évite la re-décomposition pendant nos
 * propres émissions (garde `_internal`) pour ne pas perdre la position des
 * sliders sur le retour de binding.
 */
Item {
    id: picker

    property color color: "#ffffff"     // entrée (bindée) / valeur courante
    signal colorPicked(color c)

    property real _h: 0                  // teinte 0..1
    property real _s: 0                  // saturation 0..1
    property real _l: 1                  // luminance 0..1
    property bool _internal: false

    implicitWidth: 220
    implicitHeight: col.implicitHeight

    onColorChanged: if (!picker._internal) picker._decompose()
    Component.onCompleted: picker._decompose()

    function _decompose() {
        if (picker.color.hslHue >= 0) picker._h = picker.color.hslHue   // -1 si achromatique → garde la teinte
        picker._s = picker.color.hslSaturation
        picker._l = picker.color.hslLightness
    }
    function _emit() {
        picker._internal = true
        picker.colorPicked(Qt.hsla(picker._h, picker._s, picker._l, 1.0))
        picker._internal = false
    }

    readonly property color _preview: Qt.hsla(picker._h, picker._s, picker._l, 1.0)

    // Poignée ronde commune (centre transparent → le dégradé transparaît).
    component Knob: Rectangle {
        width: 18; height: 18; radius: 9
        color: "transparent"
        border.color: "white"; border.width: 3
        Rectangle { anchors.fill: parent; anchors.margins: -2; radius: 11
            color: "transparent"; border.color: "#66000000"; border.width: 1 }
    }

    ColumnLayout {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 5

        // Aperçu + hex
        RowLayout {
            Layout.fillWidth: true; spacing: 6
            Rectangle { width: 22; height: 22; radius: 4
                color: picker._preview; border.color: "#555"; border.width: 1 }
            Label { Layout.fillWidth: true
                text: picker._preview.toString().toUpperCase()
                color: "#9ca3af"; font.pixelSize: 10 }
        }

        // Teinte (arc-en-ciel)
        Slider {
            id: hueS
            Layout.fillWidth: true; implicitHeight: 22
            from: 0; to: 1
            value: picker._h
            onMoved: { picker._h = value; picker._emit() }
            background: Rectangle {
                x: hueS.leftPadding
                y: hueS.topPadding + hueS.availableHeight / 2 - height / 2
                width: hueS.availableWidth; height: 12; radius: 6
                border.color: "#3a3a3a"; border.width: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.000; color: "#ff0000" }
                    GradientStop { position: 0.166; color: "#ffff00" }
                    GradientStop { position: 0.333; color: "#00ff00" }
                    GradientStop { position: 0.500; color: "#00ffff" }
                    GradientStop { position: 0.666; color: "#0000ff" }
                    GradientStop { position: 0.833; color: "#ff00ff" }
                    GradientStop { position: 1.000; color: "#ff0000" }
                }
            }
            handle: Knob {
                x: hueS.leftPadding + hueS.visualPosition * (hueS.availableWidth - width)
                y: hueS.topPadding + hueS.availableHeight / 2 - height / 2
            }
        }

        // Saturation (gris → couleur pleine)
        Slider {
            id: satS
            Layout.fillWidth: true; implicitHeight: 22
            from: 0; to: 1
            value: picker._s
            onMoved: { picker._s = value; picker._emit() }
            background: Rectangle {
                x: satS.leftPadding
                y: satS.topPadding + satS.availableHeight / 2 - height / 2
                width: satS.availableWidth; height: 12; radius: 6
                border.color: "#3a3a3a"; border.width: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.hsla(picker._h, 0, picker._l, 1) }
                    GradientStop { position: 1.0; color: Qt.hsla(picker._h, 1, picker._l, 1) }
                }
            }
            handle: Knob {
                x: satS.leftPadding + satS.visualPosition * (satS.availableWidth - width)
                y: satS.topPadding + satS.availableHeight / 2 - height / 2
            }
        }

        // Luminance (noir → couleur → blanc)
        Slider {
            id: lumS
            Layout.fillWidth: true; implicitHeight: 22
            from: 0; to: 1
            value: picker._l
            onMoved: { picker._l = value; picker._emit() }
            background: Rectangle {
                x: lumS.leftPadding
                y: lumS.topPadding + lumS.availableHeight / 2 - height / 2
                width: lumS.availableWidth; height: 12; radius: 6
                border.color: "#3a3a3a"; border.width: 1
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: Qt.hsla(picker._h, picker._s, 0, 1) }
                    GradientStop { position: 0.5; color: Qt.hsla(picker._h, picker._s, 0.5, 1) }
                    GradientStop { position: 1.0; color: Qt.hsla(picker._h, picker._s, 1, 1) }
                }
            }
            handle: Knob {
                x: lumS.leftPadding + lumS.visualPosition * (lumS.availableWidth - width)
                y: lumS.topPadding + lumS.availableHeight / 2 - height / 2
            }
        }
    }
}
