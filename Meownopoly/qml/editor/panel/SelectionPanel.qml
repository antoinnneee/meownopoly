import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import AssetManager
import ".."

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
    
    // Propriétés de redimensionnement
    property int customHeight: 400 // Hauteur personnalisée de l'utilisateur
    property int minHeight: 100 // Hauteur minimale configurable
    property int maxHeight: parent.height * 0.7 // Hauteur maximale dynamique
    property bool isResizing: false // État de redimensionnement actif
    property real resizeSensitivity: 1.5 // Sensibilité du redimensionnement (évite les micro-mouvements)
    
    // Dimensions à propager vers les panels enfants
    readonly property int collapsedHeight: 0
    readonly property int expandedHeight: customHeight
    height: isExpanded ? expandedHeight : collapsedHeight // Hauteur explicite
    
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
    
    // Signaux de redimensionnement
    signal resizeStarted()
    signal resizeFinished(int finalHeight)


    required property EditorLogic logic

    // Persistance de la hauteur personnalisée
    Component.onCompleted: {
        loadCustomHeight()
    }
    
    Component.onDestruction: {
        saveCustomHeight()
    }
    
    function saveCustomHeight() {
        // Sauvegarder la hauteur personnalisée dans les paramètres
        if (typeof Settings !== 'undefined') {
            Settings.setValue("SelectionPanel/customHeight", root.customHeight)
        }
    }
    
    function loadCustomHeight() {
        // Charger la hauteur personnalisée depuis les paramètres
        if (typeof Settings !== 'undefined') {
            var savedHeight = Settings.value("SelectionPanel/customHeight", 400)
            root.customHeight = Math.max(root.minHeight, Math.min(savedHeight, root.maxHeight))
        }
    }
    
    function resetToDefaultHeight() {
        root.customHeight = 400
        saveCustomHeight()
    }

    // Smooth height animation
    Behavior on height {
        NumberAnimation {
            duration: 50 // Animation plus rapide pour le redimensionnement
        }
    }

    MenuSelector {
        id: topToolbar
        isExpanded: root.isExpanded
        onIsExpandedChanged: {
            root.isExpanded = isExpanded
        }

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.top
        height: 35
        z: 10


        logic: root.logic

        onButtonClicked: function(index) {
            console.log("Bouton cliqué avec index : " + index);
            // Changer le panneau affiché en fonction de l'index du bouton
            root.currentPanelIndex = index;
            stackView.currentIndex = index;
        }
    }

    // Zone de redimensionnement
    Rectangle {
        id: resizeHandle
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 10
        color: root.isResizing ? "#E6333333" : "#E6000000"
        z: 15
        
        // Indicateur visuel subtil
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.3
            height: 2
            color: resizeMouseArea.containsMouse || root.isResizing ? "#4A90E2" : "#CCCCCC"
            radius: 1
        }
        
        MouseArea {
            id: resizeMouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.SizeVerCursor
            enabled: root.isExpanded
            
            property real startY: 0
            property real startHeight: 0
            
            onPressed: function(mouse) {
                if (!root.isExpanded) return
                startY = mouse.y
                startHeight = root.customHeight
                root.isResizing = true
                root.resizeStarted()
                mouse.accepted = true
            }
            
            onPositionChanged: function(mouse) {
                if (!root.isResizing) return
                
                var deltaY = mouse.y - startY
                var newHeight = startHeight - (deltaY * root.resizeSensitivity)
                
                // Appliquer les limites
                newHeight = Math.max(root.minHeight, Math.min(newHeight, root.maxHeight))
                
                // Éviter les mises à jour inutiles pour réduire le tremblement
                if (Math.abs(newHeight - root.customHeight) > 1) {
                    root.customHeight = newHeight
                }
                
                mouse.accepted = true
            }
            
            onReleased: function(mouse) {
                if (root.isResizing) {
                    root.isResizing = false
                    root.resizeFinished(root.customHeight)
                }
                mouse.accepted = true
            }
            
            onCanceled: {
                if (root.isResizing) {
                    root.isResizing = false
                    root.resizeFinished(root.customHeight)
                }
            }
        }
        
        // Animation de couleur au survol
        Behavior on color {
            ColorAnimation { duration: 150 }
        }
    }


    // Content area with stacked views
    color: "transparent"


    // Stack layout to switch between panels
    StackLayout {
        id: stackView
        anchors.fill: parent
        anchors.topMargin: resizeHandle.height // Prendre en compte la zone de redimensionnement
        currentIndex: root.currentPanelIndex
        visible: true // Assurer que le StackLayout est visible


        // Asset Selection Panel
        AssetSelectionPanel {
            id: assetPanel
            logic: root.logic

            Layout.preferredHeight: root.expandedHeight

            collapsedHeight: root.collapsedHeight
            expandedHeight: root.expandedHeight
            Layout.preferredWidth: parent.width
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

            Layout.preferredHeight: root.expandedHeight

            collapsedHeight: root.collapsedHeight
            expandedHeight: root.expandedHeight
            Layout.preferredWidth: parent.width
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
        if (root.currentPanelIndex === 0) {
            // Si nous sommes sur le panel d'assets
            assetPanel.assetManagerSettings.clearAssetSelection()
        }
    }

}
