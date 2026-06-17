import QtQuick
import theme
import ui_item

/*
 * CSP_ClearButton — bouton « effacer la sélection de case ».
 * Wrapper MeowButton (variant danger + icône ✕).
 */
MeowButton {
    variant: "danger"
    iconText: "✕"
    text: "Clear"
    fontSize: Theme.fontSizeSmall

    onClicked: {
        // Signal to parent to clear selection
        titleBar.caseSelected("", "")
    }
}
