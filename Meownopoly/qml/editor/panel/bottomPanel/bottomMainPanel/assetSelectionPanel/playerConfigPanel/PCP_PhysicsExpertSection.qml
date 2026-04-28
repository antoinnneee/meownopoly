import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import EditorOpBus

/*
 * Section "Expert" : 8 sliders complets.
 * Capture before/after via mapInfo.toJSON() autour de la mutation pour
 * Game.updateMapMetadata (autosave) ; broadcast collab via
 * EditorOpBus.submitOp(UpdatePlayerProfile {field: value}).
 */
ColumnLayout {
    id: root

    property var profile: null
    property var mapInfo: null

    spacing: Screen.pixelDensity * 2

    component LabelledSlider: RowLayout {
        property string label
        property string fieldName        // nom JSON du champ
        property real minValue
        property real maxValue
        property real step
        property real value
        property int  decimals: 2
        property string _beforeJson: ""

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
                    root._commit(parent._beforeJson, parent.fieldName, value)
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

    function _commit(beforeJson, fieldName, value) {
        if (!root.profile || !root.mapInfo || !fieldName) return
        root.profile[fieldName] = value
        Game.updateMapMetadata(beforeJson, root.mapInfo.toJSON())
        const fields = {}
        fields[fieldName] = value
        EditorOpBus.submitOp(EditorOpBus.makeUpdatePlayerProfileOp(
                                root.profile.id, fields))
    }

    LabelledSlider {
        Layout.fillWidth: true
        label: "Taille (radius)"; fieldName: "radius"
        minValue: 0.1; maxValue: 1.5; step: 0.05; decimals: 2
        value: root.profile ? root.profile.radius : 0.4
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Masse"; fieldName: "mass"
        minValue: 0.1; maxValue: 10.0; step: 0.1; decimals: 1
        value: root.profile ? root.profile.mass : 1.0
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Accélération"; fieldName: "acceleration"
        minValue: 5; maxValue: 100; step: 1; decimals: 0
        value: root.profile ? root.profile.acceleration : 30
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Vitesse max"; fieldName: "maxSpeed"
        minValue: 50; maxValue: 800; step: 10; decimals: 0
        value: root.profile ? root.profile.maxSpeed : 300
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Linear damping"; fieldName: "linearDamping"
        minValue: 0.0; maxValue: 1.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.linearDamping : 0.1
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Friction statique"; fieldName: "staticFriction"
        minValue: 0.0; maxValue: 2.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.staticFriction : 0.4
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Friction dynamique"; fieldName: "dynamicFriction"
        minValue: 0.0; maxValue: 2.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.dynamicFriction : 0.2
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Bounce"; fieldName: "bounceFactor"
        minValue: 0.0; maxValue: 1.0; step: 0.05; decimals: 2
        value: root.profile ? root.profile.bounceFactor : 0.1
    }
}
