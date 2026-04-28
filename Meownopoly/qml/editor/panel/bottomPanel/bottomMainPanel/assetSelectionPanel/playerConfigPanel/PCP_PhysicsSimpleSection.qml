import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game

/*
 * Section "Simple" : 3 sliders Taille / Poids / Vitesse.
 * Capture before/after via mapInfo.toJSON() autour de la mutation, pour que
 * le commit dans Game.updateMapMetadata soit cohérent.
 */
ColumnLayout {
    id: root

    property var profile: null
    property var mapInfo: null

    spacing: Screen.pixelDensity * 1.5

    component LabelledSlider: RowLayout {
        property string label
        property real minValue
        property real maxValue
        property real step
        property string unitText: ""
        property real value
        property string _beforeJson: ""
        property var captureFn: null

        spacing: Screen.pixelDensity * 2

        Label {
            text: label
            color: "#cccccc"
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            Layout.preferredWidth: Screen.pixelDensity * 25
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            from: minValue
            to: maxValue
            stepSize: step
            value: parent.value
            snapMode: Slider.SnapAlways
            property bool _wasPressed: false
            onPressedChanged: {
                if (pressed && !_wasPressed) {
                    parent._beforeJson = root.mapInfo ? root.mapInfo.toJSON() : ""
                } else if (!pressed && _wasPressed) {
                    if (parent.captureFn) parent.captureFn(parent._beforeJson, value)
                }
                _wasPressed = pressed
            }
        }
        Label {
            text: slider.value.toFixed(step < 1 ? 2 : 0) + (unitText ? " " + unitText : "")
            color: "#aaaaaa"
            font.pixelSize: Math.round(Screen.pixelDensity * 2.8)
            Layout.preferredWidth: Screen.pixelDensity * 18
            horizontalAlignment: Text.AlignRight
        }
    }

    function _commit(beforeJson, applyFn) {
        if (!root.profile || !root.mapInfo) return
        applyFn()
        Game.updateMapMetadata(beforeJson, root.mapInfo.toJSON())
    }

    LabelledSlider {
        Layout.fillWidth: true
        label: "Taille"
        minValue: 0.1; maxValue: 1.5; step: 0.05
        value: root.profile ? root.profile.radius : 0.4
        captureFn: (b, v) => root._commit(b, () => { root.profile.radius = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Poids"
        minValue: 0.1; maxValue: 10.0; step: 0.1
        value: root.profile ? root.profile.mass : 1.0
        captureFn: (b, v) => root._commit(b, () => { root.profile.mass = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Vitesse"
        minValue: 50; maxValue: 800; step: 10
        value: root.profile ? root.profile.maxSpeed : 300
        captureFn: (b, v) => root._commit(b, () => { root.profile.maxSpeed = v })
    }
}
