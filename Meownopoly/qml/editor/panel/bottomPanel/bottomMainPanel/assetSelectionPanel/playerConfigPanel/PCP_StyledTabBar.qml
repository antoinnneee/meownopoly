import QtQuick
import QtQuick.Controls

/*
 * TabBar stylé. Utilisé conjointement avec PCP_StyledTabButton pour
 * harmoniser les onglets avec le reste de l'éditeur.
 */
TabBar {
    id: control

    background: Rectangle {
        color: "#1a1a1a"
        radius: 3
        border.color: "#444444"
        border.width: 1
    }
}
