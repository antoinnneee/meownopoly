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

        delegate: Button {
            text: modelData
            font.pixelSize: Math.round(Screen.pixelDensity * 2.8)
            padding: Screen.pixelDensity * 1.5
            onClicked: root.presetChosen(modelData)
        }
    }
}
