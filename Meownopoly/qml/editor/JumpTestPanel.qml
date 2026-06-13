/*
 * JumpTestPanel — Phase 8 (Y visuel 2.5D présentation).
 *
 * Petit badge top-right (sous PhysicsNetworkPanel) avec deux actions :
 *  - "Jump" : lance un saut visuel sur le PhysicsActor du joueur local
 *    (parabole approximée OutQuad/InQuad sur visualY).
 *  - "Wave" : sinusoïde infinie autour de restY (toggleable).
 *
 * Aucune touche au moteur physique : seul `node3D.y` est animé via
 * PhysicsActor.visualY. La collision (rayon, position grille) reste
 * inchangée — c'est précisément le critère de sortie de la Phase 8.
 */
import QtQuick 2.15
import QtQuick.Controls
import theme

Item {
    id: root

    // PhysicsActor du joueur principal (P1). Optionnel : le 2e (P2) est
    // ciblé séparément via la touche "+" du panel quand multi-actor est ON.
    required property var actor

    // Placement dans la Column `leftBadgeStack` d'Editor.qml.
    width: badge.width
    height: badge.height

    // L'état "Wave actif" est local au panel — on ne stocke rien côté actor
    // (il a juste son anim courante). Toggle relâche l'anim via stopVisualY().
    property bool _waveOn: false

    Rectangle {
        id: badge
        width: badgeRow.implicitWidth + 16
        height: badgeRow.implicitHeight + 10
        radius: Theme.radiusM
        color: root._waveOn ? "#3b1d4d" : Theme.surface
        border.color: root._waveOn ? "#a855f7" : Theme.borderLight
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: Theme.spacingS

            Rectangle {
                width: 10; height: 10; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: root._waveOn ? "#a855f7" : Theme.borderLight
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "2.5D"
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }

            // Séparateur visuel
            Rectangle {
                width: 1
                height: 14
                color: Theme.borderLight
                anchors.verticalCenter: parent.verticalCenter
            }

            // Bouton Jump
            Rectangle {
                id: jumpBtn
                width: jumpText.implicitWidth + 12
                height: 18
                radius: Theme.radiusS
                anchors.verticalCenter: parent.verticalCenter
                color: jumpMa.containsMouse
                       ? (jumpMa.pressed ? Theme.surfaceHover : Theme.surfaceAlt)
                       : "transparent"
                border.color: Theme.borderLight
                border.width: 1
                Text {
                    id: jumpText
                    anchors.centerIn: parent
                    text: "Jump"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeCaption
                    font.bold: true
                }
                MouseArea {
                    id: jumpMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.actor) return
                        // Si une vague tourne, on l'éteint avant de sauter pour
                        // que jump reparte de restY proprement.
                        root._waveOn = false
                        root.actor.jump(80, 600)
                    }
                }
                ToolTip.visible: jumpMa.containsMouse
                ToolTip.delay: 400
                ToolTip.text: "Saut visuel (height=80, duration=600 ms). N'affecte pas la collision."
            }

            // Bouton Wave (toggle)
            Rectangle {
                id: waveBtn
                width: waveText.implicitWidth + 12
                height: 18
                radius: Theme.radiusS
                anchors.verticalCenter: parent.verticalCenter
                color: root._waveOn
                       ? "#6b21a8"
                       : (waveMa.containsMouse
                            ? (waveMa.pressed ? Theme.surfaceHover : Theme.surfaceAlt)
                            : "transparent")
                border.color: root._waveOn ? "#a855f7" : Theme.borderLight
                border.width: 1
                Text {
                    id: waveText
                    anchors.centerIn: parent
                    text: root._waveOn ? "Wave ✓" : "Wave"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeCaption
                    font.bold: true
                }
                MouseArea {
                    id: waveMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!root.actor) return
                        if (root._waveOn) {
                            root.actor.stopVisualY()
                            root._waveOn = false
                        } else {
                            root.actor.wave(40, 1200)
                            root._waveOn = true
                        }
                    }
                }
                ToolTip.visible: waveMa.containsMouse
                ToolTip.delay: 400
                ToolTip.text: "Sinusoïde infinie (amplitude=40, period=1.2 s). Click pour stopper."
            }
        }
    }
}
