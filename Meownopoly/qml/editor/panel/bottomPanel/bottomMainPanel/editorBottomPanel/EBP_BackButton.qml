import QtQuick
import theme
import ui_item

/*
 * EBP_BackButton — bouton retour du panneau d'édition.
 * Wrapper MeowButton (variant ghost + icône ←).
 */
MeowButton {
    visible: true
    variant: "ghost"
    iconText: "←"
    text: "Back"
    fontSize: Theme.fontSizeMedium
}
