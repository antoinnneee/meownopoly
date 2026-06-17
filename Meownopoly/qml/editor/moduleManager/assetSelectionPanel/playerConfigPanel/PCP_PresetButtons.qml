import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/*
 * Row de boutons de presets physiques.
 * Émet presetChosen(name) — le parent appelle profile.applyPreset(name).
 */
Flow {
    id: root

    property var presets: ["Standard", "Léger", "Lourd", "Glissant", "Adhérent"]
    signal presetChosen(string name)

    spacing: Screen.pixelDensity * 1.5

    Repeater {
        model: root.presets

        delegate: PCP_StyledButton {
            text: modelData
            onClicked: root.presetChosen(modelData)
        }
    }
}
