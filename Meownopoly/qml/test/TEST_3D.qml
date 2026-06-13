pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers
import Case
import CaseRestArea
import theme

Rectangle {
    id: root
    width: 800
    height: 600
    color: Theme.surface

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacingL
        
        Rectangle{
            id: viewArea
            Layout.preferredWidth: root.width * 0.7
            Layout.preferredHeight: root.height * 0.8
            color: Theme.surfaceHover
            Layout.alignment: Qt.AlignCenter
            border.width: 1

            Node {
                id: scene

                DirectionalLight {
                    x: 0
                    y: 264.806
                    z: 335.38977
                    ambientColor: Qt.rgba(0.5, 0.5, 0.5, 1.0)
                    brightness: 1.0
                    eulerRotation.x: -25
                }
                // PrincessV2{
                //     x: 36.227
                //     y: -15.472
                //     z: 13.55649

                // }

                // Stationary orthographic camera viewing from the top
                OrthographicCamera {
                    id: cameraOrthographic
                    x: -470.147
                    y: 275.071
                    eulerRotation.z: 0.00022
                    eulerRotation.y: -62.00133
                    pivot.x: 0
                    z: 258.01538
                    eulerRotation.x: -30.00013
                }
            }

            View3D {
                anchors.fill: parent
                camera:cameraOrthographic
                importScene: scene

                environment: SceneEnvironment {
                    backgroundMode: SceneEnvironment.Transparent
                }

            }


        }

        // Control panel for camera rotation
        Rectangle {
            Layout.preferredWidth: root.width * 0.25
            Layout.preferredHeight: root.height * 0.8
            color: Theme.surfaceHover
            Layout.alignment: Qt.AlignCenter
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingHuge

                Label {
                    text: "Camera Position"
                    color: Theme.textPrimary
                    font.bold: true
                    font.pixelSize: Theme.fontSizeLarge
                    Layout.alignment: Qt.AlignHCenter
                }

                // X Position
                ColumnLayout {
                    spacing: Theme.spacingXS
                    Label {
                        text: "X Position: " + xPositionSlider.value.toFixed(0)
                        color: Theme.textPrimary
                    }
                    Slider {
                        id: xPositionSlider
                        from: -1000
                        to: 1000
                        value: -600
                        onValueChanged: cameraOrthographic.x = value
                        Layout.fillWidth: true
                    }
                }

                // Y Position
                ColumnLayout {
                    spacing: Theme.spacingXS
                    Label {
                        text: "Y Position: " + yPositionSlider.value.toFixed(0)
                        color: Theme.textPrimary
                    }
                    Slider {
                        id: yPositionSlider
                        from: -1000
                        to: 1000
                        value: 0
                        onValueChanged: cameraOrthographic.y = value
                        Layout.fillWidth: true
                    }
                }

                // Z Position
                ColumnLayout {
                    spacing: Theme.spacingXS
                    Label {
                        text: "Z Position: " + zPositionSlider.value.toFixed(0)
                        color: Theme.textPrimary
                    }
                    Slider {
                        id: zPositionSlider
                        from: -1000
                        to: 1000
                        value: 0
                        onValueChanged: cameraOrthographic.z = value
                        Layout.fillWidth: true
                    }
                }

                Label {
                    text: "Camera Rotation"
                    color: Theme.textPrimary
                    font.bold: true
                    font.pixelSize: Theme.fontSizeLarge
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Theme.spacingHuge
                }

                // X Rotation
                ColumnLayout {
                    spacing: Theme.spacingXS
                    Label {
                        text: "X Rotation: " + xRotationSlider.value.toFixed(1)
                        color: Theme.textPrimary
                    }
                    Slider {
                        id: xRotationSlider
                        from: -180
                        to: 180
                        value: 0
                        onValueChanged: cameraOrthographic.eulerRotation.x = value
                        Layout.fillWidth: true
                    }
                }

                // Y Rotation
                ColumnLayout {
                    spacing: Theme.spacingXS
                    Label {
                        text: "Y Rotation: " + yRotationSlider.value.toFixed(1)
                        color: Theme.textPrimary
                    }
                    Slider {
                        id: yRotationSlider
                        from: -180
                        to: 180
                        value: -90
                        onValueChanged: cameraOrthographic.eulerRotation.y = value
                        Layout.fillWidth: true
                    }
                }

                // Z Rotation
                ColumnLayout {
                    spacing: Theme.spacingXS
                    Label {
                        text: "Z Rotation: " + zRotationSlider.value.toFixed(1)
                        color: Theme.textPrimary
                    }
                    Slider {
                        id: zRotationSlider
                        from: -180
                        to: 180
                        value: 0
                        onValueChanged: cameraOrthographic.eulerRotation.z = value
                        Layout.fillWidth: true
                    }
                }

                // Spacer
                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    Item {
        id: __materialLibrary__

        DefaultMaterial {
            objectName: ""
            diffuseColor: Qt.rgba(0.8, 0.8, 0.4, 1.0)
        }
    }
}


