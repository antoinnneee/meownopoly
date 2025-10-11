import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtCore
import QtQuick.Effects
import AssetManager
import ".."

import "./assetSelectionPanel"
import "./caseSelectionPanel"
import "./mapSelectionPanel"
Rectangle {
    id: root

    // Properties
    property bool isExpanded: true
    // property string currentView: "categories" // "categories" or "assets"
    property int currentPanelIndex: 0 // 0 = Asset Selection, 1 = Case Selection
    onCurrentPanelIndexChanged: {
        clearAssetSelection()
    }
    
    // Propriétés de redimensionnement
    property int customHeight: Screen.pixelDensity * 75// Hauteur personnalisée de l'utilisateur
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
    property alias assetView: assetPanel.currentView

    property alias caseTypeSelected: casePanel.selectedCaseType
    property alias casePanel: casePanel
    property alias connectionsPanel: casePanel.connectionsConfigSection  // Exposer le panneau de connexions

    // Signals to propagate from child panels
    // Signaux pour propager les événements vers l'Editor
    signal assetSelected(string category, string type, string id)
    signal assetCleared()
    signal caseSelected(string category, string type, string id)
    // signal selectionModeChanged(bool isActive)

    signal viewChanged(string viewName)
    signal visualEffectChanged()
    
    // Signaux de redimensionnement
    signal resizeStarted()
    signal resizeFinished(int finalHeight)

    signal effectChanged()
    signal connectionRequested(string kind)  // Propager les demandes de connexion

    required property EditorLogic logic

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
        Behavior on color { ColorAnimation { duration: 150 }}
    }

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

            collapsedHeight: root.collapsedHeight
            expandedHeight: root.expandedHeight
            Layout.preferredWidth: parent.width
            isExpanded: root.isExpanded

            Layout.preferredHeight: root.expandedHeight

            onAssetSelected: function(category, type, id) {
                if (category === "" && type === "" && id === "") {
                    // root.assetCleared()
                    // root.clearAssetSelection()
                }
                else {
                    root.assetSelected(category, type, id);
                }
            }
            onAssetCleared: {
                root.clearAssetSelection()
            }

            // Surveiller les changements de propriétés pour propager les signaux
            onCurrentViewChanged: {
                root.viewChanged(currentView);
            }

            onEffectChanged: {
                root.effectChanged()
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
            isExpanded: true
            
            onConnectionRequested: function(kind) {
                root.connectionRequested(kind)
            }

        }

        // Case Selection Panel
        MapSelectionPanel {
            id: mapPanel
            logic: root.logic

            Layout.preferredHeight: root.expandedHeight

            collapsedHeight: root.collapsedHeight
            expandedHeight: root.expandedHeight
            Layout.preferredWidth: parent.width
            isExpanded: root.isExpanded

        }
    }

    // Fonction pour effacer la sélection d'asset
    function clearAssetSelection() {
        assetPanel.assetManagerSettings.clearAssetSelection()
        casePanel.clearSelection()
        assetCleared()
    }

}
