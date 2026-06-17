import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import world3d 1.0
import theme

// Conteneur bespoke du module "Config 3D" (D5). Surface les contrôles caméra
// existants (CameraRig) : mode, lissage Follow, paramètres OrbitDebug — version
// productisée du CameraTestPanel (dev badge). Affiché/positionné par Editor.qml
// quand la vignette "config3d" est active.
Rectangle {
    id: root

    required property var cameraRig

    color: "#E6000000"
    border.color: Theme.surfaceAlt
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingM
        spacing: Theme.spacingXL

        // --- Mode caméra ---
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            spacing: Theme.spacingXS
            Text {
                text: "Mode caméra"
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeSmall
            }
            GridLayout {
                columns: 2
                columnSpacing: Theme.spacingXS
                rowSpacing: Theme.spacingXS
                Repeater {
                    model: root.cameraRig ? [
                        { label: "Follow",       value: CameraRig.Follow },
                        { label: "FreeCam",      value: CameraRig.FreeCam },
                        { label: "FixedTopDown", value: CameraRig.FixedTopDown },
                        { label: "OrbitDebug",   value: CameraRig.OrbitDebug }
                    ] : []
                    delegate: Rectangle {
                        width: 110
                        height: 26
                        radius: Theme.radiusS
                        readonly property bool active:
                            root.cameraRig && root.cameraRig.mode === modelData.value
                        color: active ? Theme.accent : Theme.surface
                        border.color: active ? Theme.hover(Theme.accent) : Theme.borderLight
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: modelData.label
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeSmall
                            font.bold: parent.active
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (root.cameraRig) root.cameraRig.setMode(modelData.value)
                        }
                    }
                }
            }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: Theme.border }

        // --- Follow ---
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: 220
            spacing: Theme.spacingXS
            Text {
                text: "Follow — lissage : " + (root.cameraRig ? root.cameraRig.smoothSpeed.toFixed(2) : "n/a")
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeSmall
            }
            Slider {
                Layout.fillWidth: true
                enabled: root.cameraRig !== null
                from: 0.1; to: 10.0; stepSize: 0.1
                value: root.cameraRig ? root.cameraRig.smoothSpeed : 2.0
                onMoved: if (root.cameraRig) root.cameraRig.smoothSpeed = value
            }
        }

        Rectangle { Layout.fillHeight: true; width: 1; color: Theme.border }

        // --- OrbitDebug ---
        ColumnLayout {
            Layout.alignment: Qt.AlignTop
            Layout.fillWidth: true
            spacing: Theme.spacingXS
            Text {
                text: "OrbitDebug"
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeSmall
            }
            Text {
                text: "Yaw : " + (root.cameraRig ? root.cameraRig.orbitYaw.toFixed(1) : "n/a") + "°"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeCaption
            }
            Slider {
                Layout.fillWidth: true
                enabled: root.cameraRig !== null
                from: -180; to: 180; stepSize: 1
                value: root.cameraRig ? root.cameraRig.orbitYaw : 0
                onMoved: if (root.cameraRig) root.cameraRig.orbitYaw = value
            }
            Text {
                text: "Pitch : " + (root.cameraRig ? root.cameraRig.orbitPitch.toFixed(1) : "n/a") + "°"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeCaption
            }
            Slider {
                Layout.fillWidth: true
                enabled: root.cameraRig !== null
                from: -89; to: 89; stepSize: 1
                value: root.cameraRig ? root.cameraRig.orbitPitch : -55
                onMoved: if (root.cameraRig) root.cameraRig.orbitPitch = value
            }
            Text {
                text: "Distance : " + (root.cameraRig ? root.cameraRig.orbitDistance.toFixed(0) : "n/a")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeCaption
            }
            Slider {
                Layout.fillWidth: true
                enabled: root.cameraRig !== null
                from: 50; to: 3000; stepSize: 10
                value: root.cameraRig ? root.cameraRig.orbitDistance : 600
                onMoved: if (root.cameraRig) root.cameraRig.orbitDistance = value
            }
        }
    }
}
