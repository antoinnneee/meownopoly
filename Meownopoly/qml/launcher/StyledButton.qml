import QtQuick
import QtQuick.Controls
import theme
import ui_item

/*
 * StyledButton.qml — Bouton custom du launcher (thème sombre).
 *
 * Désormais un mince wrapper au-dessus de MeowButton : il conserve l'API
 * historique (`primary` / `danger` / `accentColor`) mais délègue tout le
 * style au composant générique.
 *
 *  - défaut       : variant "secondary" (fond surface neutre)
 *  - primary:true : rempli avec `accentColor`
 *  - danger:true  : variant "danger" (rouge)
 *
 * Rendu plat (sans brillance ni zoom au survol) pour s'intégrer aux
 * panneaux denses du launcher.
 */
MeowButton {
    id: control

    property color accentColor: Theme.accentAlt
    property bool  primary: false
    property bool  danger: false

    variant: control.danger ? "danger"
           : control.primary ? "primary"
           : "secondary"
    baseColor: control.primary ? control.accentColor : control._variantColor

    hoverZoom: false
    glossy: false

    implicitHeight: 30
    leftPadding: Theme.spacingXL
    rightPadding: Theme.spacingXL

    // Conserve la possibilité de régler la taille via `font.pixelSize`
    // (comme un Button standard), tout en alimentant `fontSize`.
    font.pixelSize: Theme.fontSizeBody
    fontSize: control.font.pixelSize
}
