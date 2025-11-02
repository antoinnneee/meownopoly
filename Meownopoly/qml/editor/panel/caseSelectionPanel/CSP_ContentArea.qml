import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "../editorBottomPanel"
import "../assetSelectionPanel"
import "main"
import "side"

EBP_Content {
    id: contentArea
    
    // Propriétés requises par EBP_Content
    currentView: "categories"
    activeFilter: "All"
    
    // Propriétés supplémentaires
    searchText: ""
    isExpanded: true
    property alias caseConfigurationPanelSection: caseConfigurationPanelSection  // Exposer pour l'accès externe
    property alias connectionsConfigSection: connectionsConfigSection  // Exposer pour l'accès externe
    property alias currentTabIndex: tabBar.currentIndex  // Exposer l'index de la TabBar pour la compatibilité
    property var logic: null  // Référence au logic pour sauvegarder
    
    // Signaux
    signal caseTypeSelected(int type, string typeName)
    signal caseTypeCleared()
    signal connectionRequested(string kind)  // Propager les demandes de connexion
    sidePanelRatio: 0.5

    property int titleHeight
    // Main content (categories/assets)
    mainContent: Item {
        id: mainContent
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        
        // Sélecteur de types de cases
        CSP_CaseTypeSelector {
            id: caseTypeSelector
            anchors.fill: parent
            currentView: contentArea.currentView
            activeFilter: contentArea.activeFilter
            
            onTypeSelected: function(type, typeName) {
                contentArea.caseTypeSelected(type, typeName)
            }
            
            onTypeCleared: function() {
                contentArea.caseTypeCleared()
            }
        }
    }

    sidePanel: Item {
        anchors.fill: parent
        
        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: - titleHeight
            spacing: 0
            
            // TabBar native QML
            TabBar {
                id: tabBar

                Layout.fillWidth: true
                Layout.preferredHeight: Screen.pixelDensity * 11
                currentIndex: 0
                background: Rectangle {
                    color: "transparent"
                }

                contentItem: ListView {
                    model: tabBar.contentModel
                    currentIndex: tabBar.currentIndex

                    spacing: tabBar.spacing
                    orientation: ListView.Horizontal
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.AutoFlickIfNeeded
                    snapMode: ListView.SnapToItem

                    highlightMoveDuration: 250
                    highlightResizeDuration: 0
                    highlightFollowsCurrentItem: true
                    highlightRangeMode: ListView.ApplyRange
                    preferredHighlightBegin: 48
                    preferredHighlightEnd: width - 48

                    highlight: Item {
                        z: 2
                    }
                }
                TabButton {
                    text: "Configuration de la Case"
                    font.pointSize: 11
                    font.bold: true
                    height: parent.height


                    
                    background: Rectangle {
                        color: tabBar.currentIndex === 0 ? "#3a3a3a" : "#2a2a2a"
                        topRightRadius:0
                        bottomRightRadius: 0
                        topLeftRadius: 8
                        bottomLeftRadius: 0
                        border.color: "#3a3a3a"
                        border.width: 1


                    }
                    
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: tabBar.currentIndex === 0 ? "#ffffff" : "#aaaaaa"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        bottomPadding: 4
                    }
                }
                
                TabButton {
                    text: "Configuration des Connexions"
                    font.pointSize: 11
                    font.bold: true
                    height: parent.height
                    
                    background: Rectangle {
                        color: tabBar.currentIndex === 1 ? "#3a3a3a" : "#2a2a2a"
                        border.color: "#3a3a3a"
                        border.width: 1
                        topRightRadius: 8
                        bottomRightRadius: 0
                        topLeftRadius: 0
                        bottomLeftRadius: 0
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: tabBar.currentIndex === 1 ? "#ffffff" : "#aaaaaa"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        bottomPadding: 4
                    }
                }
            }
            
            // StackLayout pour les contenus des onglets
            StackLayout {
                id: stackLayout
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: tabBar.currentIndex
                onCurrentIndexChanged: {
                    if (currentIndex === 1)
                    {
                        logic.tileLogic.displayLinkEnable = true
                    }
                    else
                    {
                        logic.tileLogic.displayLinkEnable = false
                    }
                }
                
                // Onglet Configuration Case
                CaseConfigurationPanelSection {
                    id: caseConfigurationPanelSection
                    logic: contentArea.logic
                    
                    // Gérer le changement de type de case
                    onRequestChangeType: function(newType) {
                        if (targetCase) {
                            console.log("Changing case type to:", newType)
                            //targetCase.type = newType
                            targetSnapableCase.snapableParameters.changeCaseDataType(newType)
                            // Mettre à jour les contrôles pour refléter le nouveau type
                            setTargetCase(targetSnapableCase)
                        }
                    }
                }
                
                // Onglet Configuration Connexions
                ConnectionsConfigurationSection {
                    id: connectionsConfigSection
                    logic: contentArea.logic
                    
                    onRequestAddConnection: function(kind) {
                        contentArea.connectionRequested(kind)
                    }
                }
            }
        }
    }
    function clearCaseSelection()
    {
        caseTypeSelector.clearCaseSelection()
    }
}
