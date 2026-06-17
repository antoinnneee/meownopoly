import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "../"
import editorBottomPanel
import caseSelectionPanel
import zonePanel
import templatePanel
import playerConfigPanel
import screenEffectPanel

EditorBottomPanel {
    id: root

    property alias activeFilter: titleBar.activeFilter

    property int selectedCaseType: -1
    property string selectedCaseTypeName: ""
    property string searchText: ""
    property alias csp_contentArea: csp_contentArea
//    isExpanded: true

    // Signaux
    signal caseTypeSelected(int type, string typeName)
    signal caseTypeCleared()

    signal focusReleased()



    property string selectedCategory: ""
    property string selectedType: ""
    property bool comingFromOtherMenu: false // Track if we're coming from another menu

    property string currentView: "categories"

    onComingFromOtherMenuChanged: {
        assetManagerSettings.clearAssetSelection()
        console.log("AssetSelectionPanel: comingFromOtherMenu changed to", comingFromOtherMenu)
    }

    property alias assetManagerSettings: assetManagerSettings
    property alias currentTabIndex: asp_contentArea.currentTabIndex
    property alias asp_contentArea: asp_contentArea

    // Index du StackLayout interne (contentArea) : 0=Déco, 1=Case, 2=Zone,
    // 3=Template, 4=Joueur, 5=Effets. Exposé pour pilotage externe par le
    // ModuleManager (D2). NB: bascule legacy via les boutons d'ASP_TitleBar
    // encore présente (retirée en D4).
    property alias contentIndex: stackView.currentIndex
    // Current selection state (from parent)
    QtObject{
        id: assetManagerSettings
        property string currentSelectedCategory: ""
        property string currentSelectedType: ""
        property string currentSelectedId: ""

        // Function to clear asset selection
        function clearAssetSelection() {
            assetManagerSettings.currentSelectedCategory = ""
            assetManagerSettings.currentSelectedType = ""
            assetManagerSettings.currentSelectedId = ""
        }
    }

    property alias currentSelectedCategory: assetManagerSettings.currentSelectedCategory
    property alias currentSelectedType: assetManagerSettings.currentSelectedType
    property alias currentSelectedId: assetManagerSettings.currentSelectedId

    property bool isAssetSelected: currentSelectedCategory !== "" && currentSelectedType !== "" && currentSelectedId !== ""

    // Selected decoration element for effects
    property bool showEffectsPanel: true

    // Signals
    signal assetSelected(string category, string type, string id)
    signal assetCleared()



    function updateSelectedAsset(category, type, id)
    {
        if (root.isAssetSelected && root.currentSelectedCategory === category && root.currentSelectedType === type && root.currentSelectedId === id) {
            root.assetCleared()
            return
        }
        root.currentSelectedCategory = category
        root.currentSelectedType = type
        root.currentSelectedId = id

        // Ajuster les dimensions au ratio natif de l'asset
        var asset = AssetManager.getAssetById(category, type, id)
        if (asset && asset.id && logic && logic.tileLogic) {
            var ratioWidth = asset.ratioWidth || 1
            var ratioHeight = asset.ratioHeight || 1
            console.log("AssetSelectionPanel: Asset sélectionné avec ratio", ratioWidth + ":" + ratioHeight)
            logic.tileLogic.adjustToNativeRatio(ratioWidth, ratioHeight)
        }

        root.assetSelected(category, type, id)

    }

    // Function to handle coming from another menu
    function setComingFromOtherMenu(value) {
        root.comingFromOtherMenu = value

        // Si on vient d'un autre menu, on ne change pas l'état, on laisse l'état actuel
        if (value) {
            console.log("AssetSelectionPanel: Coming from other menu, keeping current state:", root.currentView)
            // Ne pas forcer de changement d'état, laisser l'état actuel
        }
    }

    function clearCaseSelection() {
        csp_contentArea.clearCaseSelection()
    }


    // Title bar
    titleBar: ASP_TitleBar {
        id: titleBar
        activeFilter: "Decoration"
        anchors.left: parent.left
        anchors.right: parent.horizontalCenter
        anchors.top: parent.top
        isExpanded: true

        onFocusReleased: {
            root.focusReleased()
        }

        onAssetSelected: function(category, type, id) {
            root.assetSelected(category, type, id)
        }
        onSearchTextChanged: root.searchText = titleBar.searchText


        onCurrentViewChanged:  {
            root.currentView = titleBar.currentView
        }

        onBackButtonClicked: {
            // Si on vient d'un autre menu, on reste dans la catégorie sélectionnée
            // Sinon, on retourne à la sélection des catégories
            if (root.comingFromOtherMenu) {
                // Rester dans la catégorie actuelle
                root.comingFromOtherMenu = false
            } else {
                // Retourner à la sélection des catégories
                root.currentView = "categories"
                root.assetCleared()
            }
        }
        onButtonClicked: function(text, index)  {
            titleBar.activeFilter = text
            stackView.currentIndex = index
            // root.currentView = "categories"
        }


        currentSelectedCategory: root.currentSelectedCategory
        currentSelectedType: root.currentSelectedType
        currentSelectedId: root.currentSelectedId

        searchText: root.searchText
        currentView: root.currentView

    }

    contentArea: StackLayout {
        id: stackView
        anchors.fill: parent
//        anchors.topMargin: resizeHandle.height // Prendre en compte la zone de redimensionnement
        currentIndex: 0
        onCurrentIndexChanged: clearAssetSelection() // Effacer la sélection d'asset lors du changement d'onglet
        visible: true // Assurer que le StackLayout est visible

        // Asset Selection Panel
        ASP_ContentArea {
            id: asp_contentArea

            currentSelectedCategory: root.currentSelectedCategory
            currentSelectedType: root.currentSelectedType
            currentSelectedId: root.currentSelectedId
            currentView: root.currentView
            activeFilter: "All"
            searchText: root.searchText
            onCategorieSelected: {
                root.currentView = "assets"
                // Mettre à jour les propriétés de catégorie sélectionnée
                root.selectedCategory = asp_contentArea.selectedCategory
                root.selectedType = asp_contentArea.selectedType
            }
            onAssetSelected: function(category, type, id) {
                root.updateSelectedAsset(category, type, id)
            }
            isExpanded: true
            titleHeight: titleBar.height

            Layout.preferredWidth: parent.width
            Layout.preferredHeight: parent.height

        }

        // Case Selection Panel
        CSP_ContentArea {
            id: csp_contentArea
            visible: true
            currentView: root.currentView
            searchText: root.searchText
            isExpanded: true
            titleHeight: titleBar.height
            logic: root.logic
            activeFilter: "All"

            Layout.preferredWidth: parent.width
            Layout.preferredHeight: parent.height

            onCaseTypeSelected: function(type, typeName) {
                console.log("CaseSelectionPanel - case type selected:", type, typeName)
                root.selectedCaseType = type
                root.selectedCaseTypeName = typeName
                root.caseTypeSelected(type, typeName)
            }
            onCaseTypeCleared: function() {
                console.log("CaseSelectionPanel - case type cleared")
                root.selectedCaseType = -1
                root.selectedCaseTypeName = ""
                root.caseTypeCleared()
            }
        }
        // Exclusion Zone Panel
        ZP_Content {
            id: exclusionZonePanel

            logic: root.logic
            isExpanded: true

            currentView: root.currentView
            activeFilter: "All"
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: parent.height
            onFocusReleased:{
                root.focusReleased()
            }
        }
        TP_Content {
            id: templatePanelContent

            logic: root.logic
            isExpanded: true

            currentView: root.currentView
            activeFilter: "All"
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: parent.height
        }

        // 5e onglet "Joueurs" — panel de configuration des profils joueurs.
        PCP_Content {
            id: playerConfigPanelContent

            logic: root.logic
            isExpanded: true

            currentView: root.currentView
            activeFilter: "All"
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: parent.height
        }

        // 6e onglet "Effets" — éditeur de la bibliothèque d'effets visuels
        // plein écran (MapInfo.screenEffects), référencés par les zones.
        SEP_Content {
            id: screenEffectPanelContent

            logic: root.logic
            isExpanded: true

            currentView: root.currentView
            activeFilter: "All"
            Layout.preferredWidth: parent.width
            Layout.preferredHeight: parent.height
        }
    }
}
