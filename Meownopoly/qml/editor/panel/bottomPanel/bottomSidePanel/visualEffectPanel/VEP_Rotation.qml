import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import ui_item
import theme

CollapsableGroupBox {
    id: control
    title: "Rotation"

    // Preset management properties
    property var colorPresets: []
    property int activePresetIndex: -1

    property bool mirrorHorizontal: false
    property bool mirrorVertical: false

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
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeBody
                Layout.fillHeight: true
            }

            MeowSlider {
                id: rotationSlider
                Layout.fillHeight: true
                Layout.fillWidth: true
                showValue: false   // afficheur d'angle "°" fourni ci-dessous
                from: -180
                to: 180
                value: 0
                stepSize: 1

                onValueChanged: {
                    control.effectChanged()
                }
            }

            Text {
                Layout.fillHeight: true
                Layout.maximumWidth: font.pixelSize
                text: Math.round(rotationSlider.value) + "°"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeBody
                width: 30
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
            }

            VEP_ButtonMirror {
                Layout.preferredWidth: 30
                Layout.fillHeight: true
                isHorizontal: true
                isMirrored: control.mirrorHorizontal
                onClicked: {
                    control.mirrorHorizontal = !control.mirrorHorizontal
                    control.effectChanged()
                }
            }

            VEP_ButtonMirror {
                Layout.preferredWidth: 30
                Layout.fillHeight: true
                isHorizontal: false
                isMirrored: control.mirrorVertical
                onClicked: {
                    control.mirrorVertical = !control.mirrorVertical
                    control.effectChanged()
                }
            }

    }
}
