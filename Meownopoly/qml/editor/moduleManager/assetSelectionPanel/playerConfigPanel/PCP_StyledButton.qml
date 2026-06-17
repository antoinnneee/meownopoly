import QtQuick
import QtQuick.Controls
import theme
import ui_item

/*
 * PCP_StyledButton — bouton stylé du panneau de configuration des joueurs.
 *
 * Mince wrapper au-dessus de MeowButton conservant l'API `accent` :
 *   - défaut      : variant "secondary" (fond surface neutre)
 *   - accent:true : variant "primary" teinté `accentAlt` (action mise en avant)
 *
 * Rendu plat (sans brillance ni zoom au survol) pour les panneaux denses.
 */
MeowButton {
    id: control

    property bool accent: false

    variant: control.accent ? "primary" : "secondary"
    baseColor: control.accent ? Theme.accentAlt : control._variantColor

    hoverZoom: false
    glossy: false

    fontSize: Theme.fontSizeBody
    leftPadding: Theme.spacingXL
    rightPadding: Theme.spacingXL
    topPadding: Theme.spacingM
    bottomPadding: Theme.spacingM
}
