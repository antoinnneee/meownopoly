import QtQuick 2.15
import TileType
import EditorEnum

import "../component/snapable"
import "../component/grid"

Item{
    id: gameDynamicComponent
    required property GridManager gameGrid
    required property var logic
    property alias snapableCaseTileComponent: snapableCaseTileComponent
    property alias snapableDecorationComponent: snapableDecorationComponent


    Component {
        id: snapableCaseTileComponent
        SnapableCaseTile {
            gridManager: gameGrid
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

    Component {
        id: snapableDecorationComponent
        SnapableDecoration {
            gridManager: gameGrid
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

