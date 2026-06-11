/*
 * CameraTestPanel — outil de test des modes caméra (Phase 5).
 *
 * Panneau flottant top-right (sous PhysicsStatusPanel) : badge collapsé
 * affichant le mode courant ; clic → déplie le panneau complet :
 *  - sélecteur de mode (Follow / FreeCam / FixedTopDown / OrbitDebug)
 *  - sliders OrbitDebug : yaw / pitch / distance
 *  - slider smoothSpeed (Follow)
 *  - actions : snapToTarget(), recomputeOffset()
 *  - lecture live de la position caméra (x, y, z, eulerRotation.x)
 *
 * Le panneau ne possède pas le cameraRig — il reçoit une référence en
 * property et appelle setMode() / orbitDelta() / snapToTarget() dessus.
 * Pas de manipulation directe de la caméra : tout passe par le rig.
 */
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

import world3d 1.0
import theme

Item {
    id: root

    // Référence au CameraRig à piloter. Si null, le panneau s'affiche en
    // mode dégradé (badge "Camera · n/a", contrôles désactivés).
    property var cameraRig: null

    // Placement dans la Column `leftBadgeStack` d'Editor.qml.
    width: expanded ? panel.width : badge.width
    height: expanded ? panel.height : badge.height

    property bool expanded: false

    // Compteur incrémenté à 10 Hz pendant que le panneau est déplié, pour
    // forcer la ré-évaluation du readout caméra (cam.x/y/z n'émettent pas
    // de signal lors d'écritures imperatives depuis CameraRig).
    property int _readoutTick: 0

    // --- Helpers ---------------------------------------------------------

    function _modeName(m) {
        if (!cameraRig) return "n/a"
        switch (m) {
        case CameraRig.Follow:       return "Follow"
        case CameraRig.FreeCam:      return "FreeCam"
        case CameraRig.FixedTopDown: return "FixedTopDown"
        case CameraRig.OrbitDebug:   return "OrbitDebug"
        }
        return "?"
    }

    // --- Badge (collapsed) ----------------------------------------------

    Rectangle {
        id: badge
        visible: !root.expanded
        anchors.top: parent.top
        anchors.right: parent.right
        width: badgeRow.implicitWidth + 20
        height: badgeRow.implicitHeight + 10
        radius: Theme.radiusM
        color: Theme.surface
        border.color: Theme.borderLight
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: Theme.spacingM
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "📷"
                font.pixelSize: Theme.fontSizeMedium
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Caméra · " + (root.cameraRig
                                     ? root._modeName(root.cameraRig.mode)
                                     : "n/a")
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = true
        }
    }

    // --- Panel (expanded) -----------------------------------------------

    Rectangle {
        id: panel
        visible: root.expanded
        anchors.top: parent.top
        anchors.right: parent.right
        width: 280
        height: panelLayout.implicitHeight + 16
        radius: Theme.radiusL
        color: Theme.background
        border.color: Theme.borderLight
        border.width: 1

        ColumnLayout {
            id: panelLayout
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            // --- Header ---
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Caméra — test"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                }
                Text {
                    text: "✕"
                    color: Theme.textHint
                    font.pixelSize: Theme.fontSizeMedium
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.expanded = false
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }

            // --- Mode buttons ---
            Text {
                text: "Mode"
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeSmall
            }
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Theme.spacingXS
                rowSpacing: Theme.spacingXS

                Repeater {
                    model: cameraRig ? [
                        { label: "Follow",       value: CameraRig.Follow },
                        { label: "FreeCam",      value: CameraRig.FreeCam },
                        { label: "FixedTopDown", value: CameraRig.FixedTopDown },
                        { label: "OrbitDebug",   value: CameraRig.OrbitDebug }
                    ] : []
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 26
                        radius: Theme.radiusS
                        readonly property bool active:
                            cameraRig && cameraRig.mode === modelData.value
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
                            onClicked: if (cameraRig) cameraRig.setMode(modelData.value)
                        }
                    }
                }
            }

            // --- Follow params ---
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
            Text {
                text: "Follow — smoothSpeed: " + (cameraRig
                        ? cameraRig.smoothSpeed.toFixed(2) : "n/a")
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeSmall
            }
            Slider {
                Layout.fillWidth: true
                enabled: cameraRig !== null
                from: 0.1
                to: 10.0
                stepSize: 0.1
                value: cameraRig ? cameraRig.smoothSpeed : 2.0
                onMoved: if (cameraRig) cameraRig.smoothSpeed = value
            }

            // --- Orbit params ---
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
            Text {
                text: "OrbitDebug"
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeSmall
            }

            Text {
                text: "Yaw: " + (cameraRig ? cameraRig.orbitYaw.toFixed(1) : "n/a") + "°"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeCaption
            }
            Slider {
                Layout.fillWidth: true
                enabled: cameraRig !== null
                from: -180; to: 180; stepSize: 1
                value: cameraRig ? cameraRig.orbitYaw : 0
                onMoved: if (cameraRig) cameraRig.orbitYaw = value
            }

            Text {
                text: "Pitch: " + (cameraRig ? cameraRig.orbitPitch.toFixed(1) : "n/a") + "°"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeCaption
            }
            Slider {
                Layout.fillWidth: true
                enabled: cameraRig !== null
                from: -89; to: 89; stepSize: 1
                value: cameraRig ? cameraRig.orbitPitch : -55
                onMoved: if (cameraRig) cameraRig.orbitPitch = value
            }

            Text {
                text: "Distance: " + (cameraRig ? cameraRig.orbitDistance.toFixed(0) : "n/a")
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeCaption
            }
            Slider {
                Layout.fillWidth: true
                enabled: cameraRig !== null
                from: 50; to: 3000; stepSize: 10
                value: cameraRig ? cameraRig.orbitDistance : 600
                onMoved: if (cameraRig) cameraRig.orbitDistance = value
            }

            // --- Actions ---
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXS

                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.radiusS
                    color: Theme.surface
                    border.color: Theme.borderLight
                    Text {
                        anchors.centerIn: parent
                        text: "Snap"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (cameraRig) cameraRig.snapToTarget()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 26
                    radius: Theme.radiusS
                    color: Theme.surface
                    border.color: Theme.borderLight
                    Text {
                        anchors.centerIn: parent
                        text: "Recompute offset"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeCaption
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (cameraRig) cameraRig.recomputeOffset()
                    }
                }
            }

            // --- Live readout ---
            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.border }
            Text {
                Layout.fillWidth: true
                // Référence à _readoutTick pour forcer la ré-évaluation
                // périodique (cf. Timer ci-dessous).
                text: {
                    root._readoutTick    // dépendance pour binding
                    const cam = cameraRig && cameraRig.world3D
                                ? cameraRig.world3D.camera : null
                    if (!cam) return "Caméra : n/a"
                    return "pos: ("
                         + cam.x.toFixed(0) + ", "
                         + cam.y.toFixed(0) + ", "
                         + cam.z.toFixed(0) + ")\n"
                         + "rot: ("
                         + cam.eulerRotation.x.toFixed(1) + "°, "
                         + cam.eulerRotation.y.toFixed(1) + "°, "
                         + cam.eulerRotation.z.toFixed(1) + "°)"
                }
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeCaption
                font.family: "monospace"
            }
        }
    }

    // Tick périodique pour rafraîchir le readout (la caméra n'émet pas
    // de signal sur x/y/z, donc on poll). 10 Hz = suffisant pour debug.
    Timer {
        running: root.expanded
        interval: 100
        repeat: true
        onTriggered: root._readoutTick++
    }
}
