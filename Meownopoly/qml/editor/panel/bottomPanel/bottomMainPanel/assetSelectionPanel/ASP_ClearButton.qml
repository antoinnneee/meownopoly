import QtQuick
import theme
import ui_item

/*
 * ASP_ClearButton — bouton « effacer la sélection d'asset ».
 * Wrapper MeowButton (variant danger + icône ✕).
 */
MeowButton {
    variant: "danger"
    iconText: "✕"
    text: "Clear"
    fontSize: Theme.fontSizeSmall

    onClicked: {
        // Signal to parent to clear selection
        titleBar.assetSelected("", "", "")
    }
}
