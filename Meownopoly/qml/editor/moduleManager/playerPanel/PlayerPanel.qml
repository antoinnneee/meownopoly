import QtQuick
import playerConfigPanel
import theme

// Conteneur bespoke du module "Joueur" (D3).
//
// Remplace l'ancien hébergement dans le StackLayout d'AssetSelectionPanel :
// chaque module a désormais son propre conteneur autonome, sans EditorBottomPanel
// ni barre d'onglets. Le contenu (PCP_Content) est réutilisé tel quel.
//
// Affiché/masqué et positionné par Editor.qml selon le module actif du
// ModuleManager. Le chrome (fond sombre semi-transparent + bordure) reprend
// l'esthétique d'EditorBottomPanel, sans le système de particules (décoratif,
// coûteux) — réintroductible si souhaité.
Rectangle {
    id: root

    required property var logic

    color: "#E6000000"
    border.color: Theme.surfaceAlt
    border.width: 1

    PCP_Content {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        logic: root.logic
        isExpanded: true
        currentView: "categories"
        activeFilter: "All"
    }
}
