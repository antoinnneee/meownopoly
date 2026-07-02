import QtQuick
import theme

// Conteneur bespoke du module "Case" (D3). Réutilise CSP_ContentArea (sélecteur
// de types de cases), sans EditorBottomPanel ni barre d'onglets. Chrome épuré.
// La sélection de type écrit l'état de pose détenu par EditorLogic via setCaseType.
Rectangle {
    id: root

    required property var logic

    color: Theme.panelSurface
    topLeftRadius: Theme.radiusL
    topRightRadius: Theme.radiusL
    border.color: Theme.border
    border.width: 1

    CSP_ContentArea {
        id: contentArea
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        isExpanded: true
        currentView: "categories"
        activeFilter: "All"
        logic: root.logic

        onCaseTypeSelected: function (type, typeName) {
            if (root.logic) root.logic.setCaseType(type)
        }
        onCaseTypeCleared: function () {
            if (root.logic) root.logic.setCaseType(-1)
        }
    }
}
