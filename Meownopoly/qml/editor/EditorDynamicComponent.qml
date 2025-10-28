import QtQuick 2.15
import TileType
import EditorEnum
import "tools"
import "tools/snapable"
import "tools/grid"

Item{
    id: editorDynamicComponent
    required property GridManager editorGrid
    required property var logic
    required property var workArea
    // required property var caseConfigPanel
    required property var selectionPanel
    property alias snapableCaseTileComponent: snapableCaseTileComponent
    property alias snapableDecorationComponent: snapableDecorationComponent


    // Composant dynamique pour créer des SnapableCaseTile
    Component {
        id: snapableCaseTileComponent
        SnapableCaseTile {
            gridManager: editorGrid
            displayLinkEnable: logic.tileLogic.displayLinkEnable === true

            // Gestion de la suppression
            onElementDeleted: function(element) {
                console.log("Suppression de l'élément:", element)
                logic.tileLogic.deleteElementsConnections(element)
                element.connectionManager.deleteLinkedConnection()
                logic.tileLogic.deleteElement(element)
            }
        }
    }
    // Composant dynamique pour créer des SnapableDecoration

    Component {
        id: snapableDecorationComponent
        SnapableDecoration {
            gridManager: editorGrid
            displayLinkEnable: logic.tileLogic.displayLinkEnable === true


            // Gestion de la suppression
            onElementDeleted: function(element) {
                logic.tileLogic.deleteElementsConnections(element)
                element.connectionManager.deleteLinkedConnection()
                logic.tileLogic.deleteElement(element)
            }

        }
    }
}

