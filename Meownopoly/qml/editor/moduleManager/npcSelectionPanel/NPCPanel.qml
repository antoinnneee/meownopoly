import QtQuick
import theme

// Conteneur bespoke du module "PNJ". Héberge NPC_Content (même dossier).
// Chrome épuré (fond + bordure), calqué sur ZonePanel. Affiché/positionné
// par Editor.qml selon le module actif du ModuleManager.
Rectangle {
    id: root

    required property var logic
    signal focusReleased()

    // Chrome unifie des panneaux editeur : surface tokenisee, coins hauts
    // arrondis (le panneau est ancre au bas de l ecran), bordure discrete.
    color: Theme.panelSurface
    topLeftRadius: Theme.radiusL
    topRightRadius: Theme.radiusL
    border.color: Theme.border
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
