import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager

import "./assetSelectionPanel"
import "./caseSelectionPanel"
Rectangle {
    id: root

    // Properties
    property bool isExpanded: true
    property string currentView: "categories" // "categories" or "assets"
    property string selectedCategory: ""
    property string selectedType: ""
    property string searchText: ""
    property string activeFilter: "All" // "All", "Decoration", "Characters"
    property int currentPanelIndex: 0 // 0 = Asset Selection, 1 = Case Selection
    
    // Dimensions à propager vers les panels enfants
    readonly property int collapsedHeight: 0
    readonly property int expandedHeight: 400
    
    // Alias pour propager les propriétés de AssetSelectionPanel
    property alias assetPanel: assetPanel
    property alias currentSelectedAssetCategory: assetPanel.currentSelectedCategory
    property alias currentSelectedAssetType: assetPanel.currentSelectedType
    property alias currentSelectedAssetId: assetPanel.currentSelectedId
    property alias isAssetSelected: assetPanel.isAssetSelected
    property alias selectedDecoration: assetPanel.selectedDecoration
    property alias activeAssetFilter: assetPanel.activeFilter
    property alias assetSearchText: assetPanel.searchText
    property alias assetView: assetPanel.currentView

    required property var logic

    // Menu sélection Asset Case Editor
    MenuSelector {
        id: topToolbar

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.top
        height: 35
        z: 10


        logic: root.logic

        onButtonClicked: function(index) {
            console.log("Bouton cliqué avec index : " + index);
            // Changer le panneau affiché en fonction de l'index du bouton
            currentPanelIndex = index;
            stackView.currentIndex = index;
        }
    }

    // Content area with stacked views
    color: "transparent"

    // Définition explicite des dimensions
    width: parent.width
    height: parent.height

    // Stack layout to switch between panels
    StackLayout {
        id: stackView
        anchors.fill: parent
        anchors.topMargin: 0
        currentIndex: currentPanelIndex
        visible: true // Assurer que le StackLayout est visible
        height: root.isExpanded ? root.expandedHeight : root.collapsedHeight

        // Asset Selection Panel
        AssetSelectionPanel {
            id: assetPanel
            logic: root.logic
            width: parent.width
            isExpanded: root.isExpanded
            // Connexion de tous les signaux pour la propagation vers l'Editor
            onSelectionModeChanged: function(isActive) {
                root.selectionModeChanged(isActive);
            }

            onAssetSelected: function(category, type, id) {
                root.assetSelected(category, type, id);
            }

            // Surveiller les changements de propriétés pour propager les signaux
            onCurrentViewChanged: {
                console.log("AssetSelectionPanel currentView changed to:", currentView)
                root.viewChanged(currentView);
                // Propager le changement vers le parent
                //root.currentView = currentView;
            }

            onActiveFilterChanged: {
                root.filterChanged(activeFilter);
            }

            onSearchTextChanged: {
                root.textSearchChanged(searchText);
            }

            Component.onCompleted: {
                // Initialisation
                console.log("AssetSelectionPanel initialisé et connecté au SelectionPanel");
            }
        }

        // Case Selection Panel
        CaseSelectionPanel {
            id: casePanel
            logic: root.logic
            width: parent.width
            isExpanded: root.isExpanded

            onSelectionModeChanged: function(isActive) {
                // Propager le signal vers le haut si nécessaire
                selectionModeChanged(isActive);
            }

            onCaseSelected: function(category, type, id) {
                // Propager le signal vers le haut si nécessaire
                caseSelected(category, type, id);
            }
        }
    }

    // Fonction pour effacer la sélection d'asset
    function clearAssetSelection() {
        if (currentPanelIndex === 0) {
            // Si nous sommes sur le panel d'assets
            assetPanel.assetManagerSettings.clearAssetSelection()
        }
    }

    // Signals to propagate from child panels
    // Signaux pour propager les événements vers l'Editor
    signal assetSelected(string category, string type, string id)
    signal caseSelected(string category, string type, string id)
    signal selectionModeChanged(bool isActive)
    // Signaux supplémentaires pour les changements de propriétés
    signal viewChanged(string viewName)
    signal filterChanged(string filterName)
    signal textSearchChanged(string searchText)
    signal visualEffectChanged()
}
