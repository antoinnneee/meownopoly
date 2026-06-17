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
 * Personnalisation rapide :
 *   - `variant` : "primary" | "secondary" | "danger" | "warning" |
 *     "success" | "ghost". Détermine `baseColor` + couleur de texte par
 *     défaut (via `Theme`). Un `baseColor` explicite reste prioritaire.
 *   - `baseColor` / `textColor` : override direct des couleurs.
 *   - `fontSize` : taille de police (défaut `Theme.fontSizeLarge`).
 *   - `iconText` : icône emoji/unicode optionnelle à gauche du libellé
 *     (ex. "🔄", "←", "✕").
 *   - `loading` : affiche un BusyIndicator et désactive le bouton.
 *
 * Le `background` et le `contentItem` restent surchargeables pour les cas
 * particuliers (gradients spécifiques, libellés calculés…).
 *
 * Sert aussi de base à ParticleButton, qui ne fait qu'ajouter l'émetteur
 * de particules par-dessus ce style.
 */
Button {
    id: control

    // ── Personnalisation rapide ──────────────────────────────────
    // Variante sémantique ; mappe vers baseColor + couleur de texte.
    property string variant: "primary"
    // Couleur principale du bouton ; dérivée de `variant`, surchargeable.
    property color baseColor: control._variantColor
    // Couleur du libellé ; dérivée de `variant`, surchargeable.
    property color textColor: control._variantTextColor
    // Taille de police du libellé et de l'icône.
    property int fontSize: Theme.fontSizeLarge
    // Icône emoji/unicode optionnelle, rendue à gauche du libellé.
    property string iconText: ""
    // Affiche un indicateur d'attente et désactive le bouton.
    property bool loading: false
    // Léger zoom au survol (à désactiver dans les grilles denses pour
    // éviter le chevauchement des voisins).
    property bool hoverZoom: true
    // Voile de brillance en haut du bouton (look « CTA »). À désactiver
    // pour un rendu plat dans les panneaux de formulaire.
    property bool glossy: true

    // ── Résolution interne des couleurs par variante ─────────────
    readonly property bool _isGhost: control.variant === "ghost"
    readonly property color _variantColor: {
        switch (control.variant) {
        case "secondary": return Theme.surface
        case "danger":    return Theme.danger
        case "warning":   return Theme.warning
        case "success":   return Theme.success
        case "ghost":     return Theme.accent   // teinte appliquée au hover/press
        case "primary":
        default:          return Theme.accent
        }
    }
    readonly property color _variantTextColor: {
        switch (control.variant) {
        case "secondary": return Theme.textSoft
        default:          return Theme.textPrimary
        }
    }

    enabled: !control.loading

    // Dimensionnement basé sur le contenu (+ padding) ; surchargeable via
    // width/height ou un Layout. Les wrappers compacts (StyledButton,
    // ClearButton…) peuvent ainsi hériter sans être forcés à une taille fixe.
    leftPadding: Theme.spacingXXL
    rightPadding: Theme.spacingXXL
    topPadding: Theme.spacingM
    bottomPadding: Theme.spacingM

    background: Rectangle {
        radius: Theme.radiusL
        border.width: 2
        color: {
            if (!control.enabled)
                return control._isGhost ? "transparent" : Theme.borderLight
            if (control._isGhost) {
                if (control.down)    return Theme.pressed(control.baseColor)
                if (control.hovered) return Theme.hover(control.baseColor)
                return "transparent"
            }
            if (control.down)    return Theme.pressed(control.baseColor)
            if (control.hovered) return Theme.hover(control.baseColor)
            return control.baseColor
        }
        border.color: {
            if (!control.enabled) return Theme.textDisabled
            if (control._isGhost)
                return control.hovered ? control.baseColor : Theme.borderLight
            return control.hovered ? Theme.surfaceLight
                                   : Theme.pressed(control.baseColor)
        }

        Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

        // Effet de brillance (masqué pour le variant ghost, fond transparent).
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacingXXS
            radius: Theme.radiusM
            visible: !control._isGhost && control.glossy
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }

    contentItem: Item {
        implicitWidth: contentRow.implicitWidth
        implicitHeight: contentRow.implicitHeight

        BusyIndicator {
            anchors.centerIn: parent
            running: control.loading
            visible: control.loading
            height: parent.height * 0.7
            width: height
        }

        Row {
            id: contentRow
            anchors.centerIn: parent
            visible: !control.loading
            spacing: (control.iconText !== "" && control.text !== "")
                         ? Theme.spacingS : 0

            Text {
                visible: control.iconText !== ""
                text: control.iconText
                font.pixelSize: control.fontSize
                font.bold: true
                color: control.enabled ? control.textColor : Theme.textDisabled
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: control.text !== ""
                text: control.text
                font.pixelSize: control.fontSize
                font.bold: true
                color: control.enabled ? control.textColor : Theme.textDisabled
                anchors.verticalCenter: parent.verticalCenter
            }
        }
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
    scale: (control.hoverZoom && hovered) ? 1.05 : 1.0
    Behavior on scale {
        NumberAnimation { duration: Theme.durationNormal; easing.type: Easing.OutQuad }
    }
}
