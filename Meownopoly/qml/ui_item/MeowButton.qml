import QtQuick
import QtQuick.Controls

import theme

/**
 * MeowButton — bouton générique de l'application.
 *
 * Style unifié dérivé du Theme : fond coloré (`baseColor`) avec états
 * down / hover / disabled, effet de brillance, feedback de scale au clic
 * et léger zoom au survol.
 *
 * Personnalisation rapide : régler `baseColor` (et au besoin `textColor`)
 * suffit dans la grande majorité des cas — inutile de redéfinir tout le
 * `background`. Le `background` et le `contentItem` restent surchargeables
 * pour les cas particuliers (gradients spécifiques, libellés calculés…).
 *
 * Sert aussi de base à ParticleButton, qui ne fait qu'ajouter l'émetteur
 * de particules par-dessus ce style.
 */
Button {
    id: control

    // ── Personnalisation rapide ──────────────────────────────────
    // Couleur principale du bouton ; états down/hover dérivés via Theme.
    property color baseColor: Theme.accent
    // Couleur du libellé.
    property color textColor: Theme.textPrimary

    width: 150
    height: 50

    background: Rectangle {
        radius: Theme.radiusL
        border.width: 2
        color: !control.enabled
                   ? Theme.borderLight
                   : (control.down
                          ? Theme.pressed(control.baseColor)
                          : (control.hovered ? Theme.hover(control.baseColor)
                                             : control.baseColor))
        border.color: !control.enabled
                          ? Theme.textDisabled
                          : (control.hovered ? Theme.surfaceLight
                                             : Theme.pressed(control.baseColor))

        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

        // Effet de brillance
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacingXXS
            radius: Theme.radiusM
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    contentItem: Text {
        text: control.text
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
        color: control.enabled ? control.textColor : Theme.textDisabled
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    // Feedback de scale au clic.
    SequentialAnimation {
        id: clickFeedback
        NumberAnimation {
            target: control; property: "scale"
            from: 1.0; to: 0.95
            duration: Theme.durationFast; easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: control; property: "scale"
            from: 0.95; to: 1.0
            duration: Theme.durationFast; easing.type: Easing.OutBounce
        }
    }

    // Déclenche le feedback via Connections plutôt qu'un handler onClicked :
    // une sous-classe (ParticleButton) peut alors définir son propre
    // onClicked sans écraser cette animation.
    Connections {
        target: control
        function onClicked() { clickFeedback.start() }
    }

    // Léger zoom au survol.
    scale: hovered ? 1.05 : 1.0
    Behavior on scale {
        NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutQuad }
    }
}
