import QtQuick
import theme

// Conteneur bespoke du module "Zone" (D3). Héberge ZP_Content (même dossier),
// sans EditorBottomPanel ni barre d'onglets. Chrome épuré (fond + bordure).
// Affiché/positionné par Editor.qml selon le module actif du ModuleManager.
Rectangle {
    id: root

    required property var logic
    signal focusReleased()

    color: Theme.panelSurface
    topLeftRadius: Theme.radiusL
    topRightRadius: Theme.radiusL
    border.color: Theme.border
    border.width: 1

    ZP_Content {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        logic: root.logic
        isExpanded: true
        currentView: "categories"
        activeFilter: "All"
        onFocusReleased: root.focusReleased()
    }
}
