import QtQuick
import QtQuick.Controls
import theme

/*
 * TabBar stylé. Utilisé conjointement avec PCP_StyledTabButton pour
 * harmoniser les onglets avec le reste de l'éditeur.
 */
TabBar {
    id: control

    background: Rectangle {
        color: Theme.background
        radius: Theme.radiusXS
        border.color: Theme.border
        border.width: 1
    }
}
