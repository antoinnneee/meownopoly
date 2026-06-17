import QtQuick
import theme

// Conteneur bespoke du module "Template" (D3). Héberge TP_Content (même dossier),
// sans EditorBottomPanel ni barre d'onglets. Chrome épuré (fond + bordure).
// Affiché/positionné par Editor.qml selon le module actif du ModuleManager.
Rectangle {
    id: root

    required property var logic

    color: "#E6000000"
    border.color: Theme.surfaceAlt
    border.width: 1

    TP_Content {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        logic: root.logic
        isExpanded: true
        currentView: "categories"
        activeFilter: "All"
    }
}
