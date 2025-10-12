pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers
import "../case"
import Case
import CaseRestArea

Rectangle {
    id: root
    width: 800
    height: 600
    color: "#2a2a2a"

    RowLayout {
        anchors.fill: parent
        spacing: 10
        
        Rectangle{
            id: viewArea
            Layout.preferredWidth: root.width * 0.7
            Layout.preferredHeight: root.height * 0.8
            color: "#3a3a3a"
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

                // Tree2{
                //     scale: Qt.vector3d(0.1, 0.1, 0.1)
                // }
                Model {
                    x: 0
                    y: -10.43
                    source: "#Cylinder"
                    z: 0
                    scale: Qt.vector3d(3, 0.1, 3)
                    materials: [
                        SpecularGlossyMaterial {
                            id: ground
                            emissiveFactor.z: 1
                            emissiveFactor.y: 1
                            emissiveFactor.x: 1
                            specularColor: "#ffffff"
                            albedoColor: "#9e56361d"
                            objectName: "ground"
                            emissiveMap: Texture {
                                sourceItem: CaseTile{
                                    width: 100
                                    height: 100
                                    // color: "white"
                                    caseData: CaseRestArea{

                                    }
                                }

                                scaleU: 4.0
                                scaleV: 4.0
                            }
                        }
                    ]
                }

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
            color: "#3a3a3a"
            Layout.alignment: Qt.AlignCenter
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 20

                Label {
                    text: "Camera Position"
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignHCenter
                }

                // X Position
                ColumnLayout {
                    spacing: 5
                    Label {
                        text: "X Position: " + xPositionSlider.value.toFixed(0)
                        color: "white"
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
                    spacing: 5
                    Label {
                        text: "Y Position: " + yPositionSlider.value.toFixed(0)
                        color: "white"
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
                    spacing: 5
                    Label {
                        text: "Z Position: " + zPositionSlider.value.toFixed(0)
                        color: "white"
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
                    color: "white"
                    font.bold: true
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 20
                }

                // X Rotation
                ColumnLayout {
                    spacing: 5
                    Label {
                        text: "X Rotation: " + xRotationSlider.value.toFixed(1)
                        color: "white"
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
                    spacing: 5
                    Label {
                        text: "Y Rotation: " + yRotationSlider.value.toFixed(1)
                        color: "white"
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
                    spacing: 5
                    Label {
                        text: "Z Rotation: " + zRotationSlider.value.toFixed(1)
                        color: "white"
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

/*##^##
Designer {
    D{i:0}D{i:3;cameraSpeed3d:25;cameraSpeed3dMultiplier:1}
}
##^##*/
