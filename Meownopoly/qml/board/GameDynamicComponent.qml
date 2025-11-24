import QtQuick 2.15
import TileType
import EditorEnum

import "../component/snapable"
import "../component/grid"
import "logic"

Item{
    id: gameDynamicComponent
    required property GridManager gameGrid
    required property var logic
    property alias snapableCaseTileComponent: snapableCaseTileComponent
    property alias snapableDecorationComponent: snapableDecorationComponent
    property alias mouseLogic_selection_comp: mouseLogic_selection_comp
    property alias scrollLogic_normal_comp: scrollLogic_normal_comp


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


    Component {
        id: mouseLogic_selection_comp
        MouseLogic_Base {
            id: mouseLogic_selection
            logic: _logic
            grid: _grid
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_selection
            }
        }
    }
    Component{
        id: scrollLogic_normal_comp
        ScrollLogic {
            id: scrollLogic_normal
            gameGrid: _grid
            logic: _logic
            Component.onCompleted: {
                logic.scrollLogic = scrollLogic_normal
            }
        }
    }

}

