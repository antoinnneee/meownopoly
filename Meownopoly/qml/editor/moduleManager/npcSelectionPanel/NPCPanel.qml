import QtQuick
import theme

// Conteneur bespoke du module "PNJ". Héberge NPC_Content (même dossier).
// Chrome épuré (fond + bordure), calqué sur ZonePanel. Affiché/positionné
// par Editor.qml selon le module actif du ModuleManager.
Rectangle {
    id: root

    required property var logic
    signal focusReleased()

    color: "#E6000000"
    border.color: Theme.surfaceAlt
    border.width: 1

    NPC_Content {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        logic: root.logic
        isExpanded: true
        currentView: "categories"
        activeFilter: "All"
        onFocusReleased: root.focusReleased()
    }
}
