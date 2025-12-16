import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import "../../../ui_item"

CollapsableGroupBox {
    id: control
    title: "Rotation"

    // Preset management properties
    property var colorPresets: []
    property int activePresetIndex: -1

    signal effectChanged()
    property alias rotationSlider: rotationSlider
    // signal colorPresetsChanged()

    // Main layout
    content: RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                text: "Angle:"
                verticalAlignment: Text.AlignVCenter
                color: "#cccccc"
                font.pointSize: 9
                Layout.fillHeight: true
            }

            Slider {
                id: rotationSlider
                Layout.fillHeight: true
                Layout.fillWidth: true
                from: -180
                to: 180
                value: 0
                stepSize: 1

                onValueChanged: {
                    root.effectChanged()
                }
            }

            Text {
                Layout.fillHeight: true
                Layout.maximumWidth: font.pixelSize
                text: Math.round(rotationSlider.value) + "°"
                color: "#cccccc"
                font.pointSize: 9
                width: 30
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }

    }
}
