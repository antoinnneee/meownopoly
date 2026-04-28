import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import EditorOpBus

/*
 * Section "Simple" : 3 sliders Taille / Poids / Vitesse.
 * Capture before/after via mapInfo.toJSON() autour de la mutation pour
 * Game.updateMapMetadata (autosave) ; broadcast collab via
 * EditorOpBus.submitOp(UpdatePlayerProfile {field: value}).
 */
ColumnLayout {
    id: root

    property var profile: null
    property var mapInfo: null

    spacing: Screen.pixelDensity * 1.5

    component LabelledSlider: RowLayout {
        property string label
        property string fieldName        // nom JSON du champ (radius, mass, ...)
        property real minValue
        property real maxValue
        property real step
        property string unitText: ""
        property real value
        property string _beforeJson: ""

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
                    root._commit(parent._beforeJson, parent.fieldName, value)
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
        label: "Taille"; fieldName: "radius"
        minValue: 0.1; maxValue: 1.5; step: 0.05
        value: root.profile ? root.profile.radius : 0.4
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Poids"; fieldName: "mass"
        minValue: 0.1; maxValue: 10.0; step: 0.1
        value: root.profile ? root.profile.mass : 1.0
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Vitesse"; fieldName: "maxSpeed"
        minValue: 50; maxValue: 800; step: 10
        value: root.profile ? root.profile.maxSpeed : 300
    }
}
