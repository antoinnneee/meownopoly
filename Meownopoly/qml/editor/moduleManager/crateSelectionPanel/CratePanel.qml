import QtQuick
import theme

// Conteneur bespoke du module "Caisses". Héberge Crate_Content (même dossier).
// Chrome épuré (fond + bordure), calqué sur EnemyPanel. Affiché/positionné
// par Editor.qml selon le module actif du ModuleManager.
Rectangle {
    id: root

    required property var logic
    signal focusReleased()

    color: Theme.panelSurface
    topLeftRadius: Theme.radiusL
    topRightRadius: Theme.radiusL
    border.color: Theme.border
    border.width: 1

    Crate_Content {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        logic: root.logic
        isExpanded: true
        currentView: "categories"
        activeFilter: "All"
        onFocusReleased: root.focusReleased()
    }
}
