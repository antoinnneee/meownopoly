import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import EditorOpBus
import theme

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
        id: lblSlider
        property string label
        property string fieldName        // nom JSON du champ (radius, mass, ...)
        property string tooltip          // description affichée au survol
        property real minValue
        property real maxValue
        property real step
        property string unitText: ""
        property real value
        property string _beforeJson: ""

        spacing: Screen.pixelDensity * 2

        Label {
            text: lblSlider.label
            color: Theme.textSecondary
            font.pixelSize: Math.round(Screen.pixelDensity * 3)
            Layout.preferredWidth: Screen.pixelDensity * 25
        }
        // Bouton d'aide (?) — visible si un tooltip est défini.
        Rectangle {
            id: helpBtn
            visible: lblSlider.tooltip !== ""
            Layout.preferredWidth: Screen.pixelDensity * 4
            Layout.preferredHeight: Screen.pixelDensity * 4
            radius: width / 2
            color: helpHover.hovered ? Theme.accent : Theme.surfaceHover
            border.color: helpHover.hovered ? Theme.hover(Theme.accent) : Theme.borderLight
            border.width: 1
            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Label {
                anchors.centerIn: parent
                text: "?"
                color: Theme.textPrimary
                font.pixelSize: Math.round(Screen.pixelDensity * 2.6)
                font.bold: true
            }
            HoverHandler {
                id: helpHover
                cursorShape: Qt.WhatsThisCursor
            }
            ToolTip.visible: helpHover.hovered
            ToolTip.text: lblSlider.tooltip
            ToolTip.delay: 200
        }
        Slider {
            id: slider
            Layout.fillWidth: true
            from: lblSlider.minValue
            to: lblSlider.maxValue
            stepSize: lblSlider.step
            value: lblSlider.value
            snapMode: Slider.SnapAlways
            property bool _wasPressed: false
            onPressedChanged: {
                if (pressed && !_wasPressed) {
                    lblSlider._beforeJson = root.mapInfo ? root.mapInfo.toJSON() : ""
                } else if (!pressed && _wasPressed) {
                    root._commit(lblSlider._beforeJson, lblSlider.fieldName, value)
                }
                _wasPressed = pressed
            }
        }
        Label {
            text: slider.value.toFixed(lblSlider.step < 1 ? 2 : 0)
                  + (lblSlider.unitText ? " " + lblSlider.unitText : "")
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
        tooltip: "Taille du body (rayon de collision et taille apparente "
               + "du modèle 3D)."
        minValue: 0.1; maxValue: 1.5; step: 0.05
        value: root.profile ? root.profile.radius : 0.4
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Poids"; fieldName: "mass"
        tooltip: "Masse inertielle. Plus le body est lourd, moins il est "
               + "poussé en collision avec un autre body."
        minValue: 0.1; maxValue: 10.0; step: 0.1
        value: root.profile ? root.profile.mass : 1.0
    }
    LabelledSlider {
        Layout.fillWidth: true
        label: "Vitesse"; fieldName: "maxSpeed"
        tooltip: "Vitesse de pointe (cap soft). Au-delà, le body est freiné "
               + "par le damping jusqu'à revenir au cap."
        minValue: 1; maxValue: 150; step: 1
        value: root.profile ? root.profile.maxSpeed : 30
    }
}
