import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs


GroupBox {
    title: "Rotation"
    id: control
    property bool isCollapsed: false


    height: (isCollapsed ? Screen.pixelDensity * 9 : mainLayout.implicitHeight)
    implicitHeight: (isCollapsed ? Screen.pixelDensity * 9 : mainLayout.implicitHeight)

    // Preset management properties
    property var colorPresets: []
    property int activePresetIndex: -1

    signal effectChanged()
    // signal colorPresetsChanged()


    padding:4
    spacing: 2

    background: Rectangle {
        color: "#333333"
        radius: 4
        border.color: "#555555"
        border.width: 1
    }

    label: MouseArea {
        id: titleLabel
        x: control.leftPadding
        width: control.availableWidth
        height: Screen.pixelDensity * 8
        onClicked: {
            control.isCollapsed = !control.isCollapsed
        }
        RowLayout {
            spacing: 8
            anchors.fill: parent

            Text {
                color: "#cccccc"
                text: control.title

                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    // Main layout
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.topMargin: titleLabel.height/2
        spacing: 1
        visible: !control.isCollapsed

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            Text {
                text: "Angle:"
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
                text: Math.round(rotationSlider.value) + "°"
                color: "#cccccc"
                font.pointSize: 9
                width: 30
                horizontalAlignment: Text.AlignRight
            }
        }
    }
}
