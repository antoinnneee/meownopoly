import QtQuick
import theme

// Conteneur bespoke du module "Déco" (D3). Réutilise les sous-composants prouvés
// ASP_TitleBar (barre recherche/back, SANS onglets : buttonModel vide) et
// ASP_ContentArea (grille catégories→assets), sans EditorBottomPanel ni
// StackLayout d'onglets. Layout (titre en haut / contenu dessous) calqué sur
// EditorBottomPanel pour préserver la géométrie éprouvée.
//
// La sélection écrit l'état de pose détenu par EditorLogic (logic.*).
Rectangle {
    id: root

    required property var logic

    // Navigation interne du browser d'assets.
    property string currentView: "categories"   // "categories" | "assets"
    property string searchText: ""
    property string selectedCategory: ""
    property string selectedType: ""

    color: Theme.panelSurface
    topLeftRadius: Theme.radiusL
    topRightRadius: Theme.radiusL
    border.color: Theme.border
    border.width: 1

    // Emplacement du titre (hauteur = celle de la barre + marge), calqué sur
    // EditorBottomPanel.titlePlaceHolder.
    Item {
        id: titleHolder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: titleBar.height + 10

        ASP_TitleBar {
            id: titleBar
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            isExpanded: true
            buttonModel: []   // pas d'onglets : le ModuleManager pilote les modules
            currentView: root.currentView
            searchText: root.searchText
            currentSelectedCategory: root.logic ? root.logic.currentSelectedAssetCategory : ""
            currentSelectedType: root.logic ? root.logic.currentSelectedAssetType : ""
            currentSelectedId: root.logic ? root.logic.currentSelectedAssetId : ""

            onSearchTextChanged: root.searchText = titleBar.searchText
            onCurrentViewChanged: root.currentView = titleBar.currentView
            onBackButtonClicked: {
                root.currentView = "categories"
                if (root.logic) root.logic.clearAssetSelection()
            }
            // Le bouton "Clear" émet assetSelected("","","").
            onAssetSelected: function (category, type, id) {
                if (category === "" && type === "" && id === "" && root.logic)
                    root.logic.clearAssetSelection()
            }
        }
    }

    Item {
        id: contentHolder
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: titleHolder.bottom
        anchors.bottom: parent.bottom

        ASP_ContentArea {
            id: contentArea
            anchors.fill: parent
            isExpanded: true
            titleHeight: titleBar.height
            activeFilter: "All"
            currentView: root.currentView
            searchText: root.searchText
            currentSelectedCategory: root.logic ? root.logic.currentSelectedAssetCategory : ""
            currentSelectedType: root.logic ? root.logic.currentSelectedAssetType : ""
            currentSelectedId: root.logic ? root.logic.currentSelectedAssetId : ""

            onCategorieSelected: {
                root.currentView = "assets"
                root.selectedCategory = contentArea.selectedCategory
                root.selectedType = contentArea.selectedType
            }
            onAssetSelected: function (category, type, id) {
                if (root.logic) root.logic.updateSelectedAsset(category, type, id)
            }
        }
    }
}
