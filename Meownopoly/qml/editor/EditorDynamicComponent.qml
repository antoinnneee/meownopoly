import QtQuick 2.15
import "tools"
import "tools/snapable"

Item{
    id: editorDynamicComponent
    required property var editorGrid
    required property var logic
    required property var workArea
    required property var caseConfigPanel
    required property var connectionsPanel
    property alias snapableCaseTileComponent: snapableCaseTileComponent
    property alias snapableDecorationComponent: snapableDecorationComponent


    // Composant dynamique pour créer des SnapableCaseTile
    Component {
        id: snapableCaseTileComponent
        SnapableCaseTile {
            gridManager: editorGrid

            // Gestion de la sélection
            onElementClicked: function(element) {
                // Désélectionner tous les autres éléments
                logic.deselectAllTiles()
                // Sélectionner l'élément cliqué
                element.isSelected = true
                logic.currentSelectedElement = element

            }
            // Gestion de la suppression
            onElementDeleted: function(element) {
                logic.deleteElementsConnections(element)
                logic.deleteElement(element)
            }
            
            // Gestion de la configuration
            onElementConfigurationRequested: function(element) {
                console.log("Configuration demandée pour:", element)
                if (element) {
                    caseConfigPanel.openConfiguration(element)
                    editorGrid.moveToConfigElement(element)

                }
            }

            onElementConnectionsConfigurationRequested: function(element) {
                if (element) {
                    connectionsPanel.targetElement = element
                    connectionsPanel.isVisible = true
                    editorGrid.moveToConfigElement(element)
                }
            }
            onElementPressed: function(element) {
                logic.deselectAllTiles()
                element.isSelected = true
                logic.currentSelectedElement = element

            }
        }
    }
        // Composant dynamique pour créer des SnapableDecoration
        
    Component {
            id: snapableDecorationComponent
            SnapableDecoration {
                gridManager: editorGrid

                // Gestion de la sélection
                onElementClicked: function(element) {
                    // Désélectionner tous les autres éléments
                    logic.deselectAllTiles()
                    // Sélectionner l'élément cliqué
                    element.isSelected = true
                    logic.currentSelectedElement = element
                }
                
                // Gestion de la suppression
                onElementDeleted: function(element) {
                    logic.deleteElementsConnections(element)
                    element.connectionManager.deleteLinkedConnection()
                    logic.deleteElement(element)
                }
                
                // Gestion de la configuration
                onElementConfigurationRequested: function(element) {
                    console.log("Configuration demandée pour:", element)
                    if (element.caseData) {
                        caseConfigPanel.openConfiguration(element)
                    }
                }

                onElementConnectionsConfigurationRequested: function(element) {
                    if (element) {
                        connectionsPanel.targetElement = element
                        connectionsPanel.isVisible = true
                        editorGrid.moveToConfigElement(element)
                    }
                }
                onElementPressed: function(element) {
                    logic.deselectAllTiles()
                    element.isSelected = true
                    logic.currentSelectedElement = element
                }

            }
        }
}
