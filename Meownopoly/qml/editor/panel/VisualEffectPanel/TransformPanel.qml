import QtQuick 2.15

import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15



GroupBox {
    id: root
    title: "Transform"
    // Properties for the target decoration element
    property bool effectsLocked: false
    property bool isCollapsed: false


    // Properties for the target decoration element
    property alias rotationSlider: rotationSlider
    property alias horizontalMirrorCheck: horizontalMirrorCheck
    property alias verticalMirrorCheck: verticalMirrorCheck
    // Dimensions
    height: (isCollapsed ? Screen.pixelDensity * 12 : mainLayout.implicitHeight +  Screen.pixelDensity * 12)

    // Signals
    signal effectChanged()

    padding: 4
    spacing: 2

    background: Rectangle {
        color: "#2a2a2a"
        radius: 8
        border.color: "#444444"
        border.width: 1
    }

    label: RowLayout {
        x: root.leftPadding
        width: root.availableWidth
        spacing: 8

        Text {
            text: root.title
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Button {
            id: collapseButton
            Layout.preferredWidth: Screen.pixelDensity * 8
            Layout.preferredHeight: Screen.pixelDensity * 8
            flat: true

            background: Rectangle {
                color: "transparent"
                border.color: "#666666"
                border.width: 1
                radius: 2
            }

            contentItem: Text {
                text: root.isCollapsed ? "▼" : "▲"
                color: "#cccccc"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                root.isCollapsed = !root.isCollapsed
            }
        }
    }

    // Main layout
    Column {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 8

        // Title with mirror buttons
        RowLayout {
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 10

            Text {
                id: title
                text: "Transform"
                color: "#ffffff"
                font.pixelSize: 14
                font.bold: true
                Layout.fillWidth: true
            }

            VEP_ButtonMirror {
                id: horizontalMirrorButton
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                isHorizontal: true
                isMirrored: horizontalMirrorCheck.checked
                onClicked: {
                    horizontalMirrorCheck.checked = !horizontalMirrorCheck.checked
                }
            }

            VEP_ButtonMirror {
                id: verticalMirrorButton
                Layout.preferredHeight: 30
                Layout.preferredWidth: 30
                isHorizontal: false
                isMirrored: verticalMirrorCheck.checked
                onClicked: {
                    verticalMirrorCheck.checked = !verticalMirrorCheck.checked
                }
            }
        }

        // Rotation Section
        Rectangle {
            id: rotationSection
            anchors.left: parent.left
            anchors.right: parent.right
            height: rotationLayout.implicitHeight + 8
            color: "#333333"
            radius: 4

            Column {
                id: rotationLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 6

                Text {
                    text: "Rotation"
                    color: "#cccccc"
                    font.pixelSize: 12
                    font.bold: true
                }

                Row {
                    spacing: 8
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Text {
                        text: "Angle:"
                        color: "#cccccc"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Slider {
                        id: rotationSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        from: -180
                        to: 180
                        value: 0
                        stepSize: 1

                        onValueChanged: {
                            root.effectChanged()
                        }
                    }

                    Text {
                        text: Math.round(rotationSlider.value) + "°"
                        color: "#cccccc"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }

        // Hidden checkboxes for mirror functionality (kept for compatibility)
        CheckBox {
            id: horizontalMirrorCheck
            visible: false
            checked: false

            onCheckedChanged: {
                root.effectChanged()
            }
        }

        CheckBox {
            id: verticalMirrorCheck
            visible: false
            checked: false

            onCheckedChanged: {
                root.effectChanged()
            }
        }
    }

    function updateFromDisplayParameter(dispParam) {
      rotationSlider.value = dispParam.rotationAngle

      // Update mirror checkboxes
      horizontalMirrorCheck.checked = dispParam.mirrorHorizontal
      verticalMirrorCheck.checked = dispParam.mirrorVertical
    }


}
