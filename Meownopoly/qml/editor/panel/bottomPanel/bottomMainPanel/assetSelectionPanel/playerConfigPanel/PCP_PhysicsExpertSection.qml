import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game

/*
 * Section "Expert" : presets + 8 sliders complets.
 * Capture before/after via mapInfo.toJSON() autour de la mutation.
 */
ColumnLayout {
    id: root

    property var profile: null
    property var mapInfo: null

    spacing: Screen.pixelDensity * 2

    component LabelledSlider: RowLayout {
        property string label
        property real minValue
        property real maxValue
        property real step
        property real value
        property int  decimals: 2
        property string _beforeJson: ""
        property var captureFn: null

        spacing: Screen.pixelDensity * 2

        Label {
            text: label
            color: "#cccccc"
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            Layout.preferredWidth: Screen.pixelDensity * 35
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
            text: slider.value.toFixed(parent.decimals)
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

    PCP_PresetButtons {
        Layout.fillWidth: true
        onPresetChosen: function(name) {
            if (!root.profile || !root.mapInfo) return
            const before = root.mapInfo.toJSON()
            root.profile.applyPreset(name)
            Game.updateMapMetadata(before, root.mapInfo.toJSON())
        }
    }

    LabelledSlider {
        Layout.fillWidth: true
        label: "Taille (radius)"
        minValue: 0.1; maxValue: 1.5; step: 0.05; decimals: 2
        value: root.profile ? root.profile.radius : 0.4
        captureFn: (b, v) => root._commit(b, () => { root.profile.radius = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Masse"
        minValue: 0.1; maxValue: 10.0; step: 0.1; decimals: 1
        value: root.profile ? root.profile.mass : 1.0
        captureFn: (b, v) => root._commit(b, () => { root.profile.mass = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Accélération"
        minValue: 5; maxValue: 100; step: 1; decimals: 0
        value: root.profile ? root.profile.acceleration : 30
        captureFn: (b, v) => root._commit(b, () => { root.profile.acceleration = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Vitesse max"
        minValue: 50; maxValue: 800; step: 10; decimals: 0
        value: root.profile ? root.profile.maxSpeed : 300
        captureFn: (b, v) => root._commit(b, () => { root.profile.maxSpeed = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Linear damping"
        minValue: 0.0; maxValue: 1.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.linearDamping : 0.1
        captureFn: (b, v) => root._commit(b, () => { root.profile.linearDamping = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Friction statique"
        minValue: 0.0; maxValue: 2.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.staticFriction : 0.4
        captureFn: (b, v) => root._commit(b, () => { root.profile.staticFriction = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Friction dynamique"
        minValue: 0.0; maxValue: 2.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.dynamicFriction : 0.2
        captureFn: (b, v) => root._commit(b, () => { root.profile.dynamicFriction = v })
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Bounce"
        minValue: 0.0; maxValue: 1.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.bounceFactor : 0.1
        captureFn: (b, v) => root._commit(b, () => { root.profile.bounceFactor = v })
    }
}
