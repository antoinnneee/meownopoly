import QtQuick 2.15
import TileType
import EditorEnum
import "../component"
import "logic"
import "../component/snapable"
import "../component/grid"

Item{
    id: editorDynamicComponent
    required property GridManager gameGrid
    required property var logic
    property alias snapableCaseTileComponent: snapableCaseTileComponent
    property alias snapableDecorationComponent: snapableDecorationComponent
    property alias mouseLogic_selection_comp: mouseLogic_selection_comp
    property alias mouseLogic_pose_comp: mouseLogic_pose_comp
    property alias mouseLogic_game_comp: mouseLogic_game_comp
    property alias mouseLogic_selectionLink_comp: mouseLogic_selectionLink_comp
    property alias mouseLogic_temp_comp: mouseLogic_temp_comp
    property alias scrollLogic_normal_comp: scrollLogic_normal_comp
    property alias scrollLogic_pose_comp: scrollLogic_pose_comp



    // Composant dynamique pour créer des SnapableCaseTile
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
    // Composant dynamique pour créer des SnapableDecoration

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
        MouseLogic_Selection {
            id: mouseLogic_selection
            logic: _logic
            grid: _grid
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_selection
                console.log("logic : ", logic)
                console.log("logic parent : ", logic.parent)
            }
        }
    }

    Component {
        id: mouseLogic_pose_comp
        MouseLogic_Pose {
            id: mouseLogic_pose
            logic: _logic
            grid: _grid
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_pose
            }
        }
    }

    Component {
        id: mouseLogic_game_comp
        MouseLogic_Game {
            id: mouseLogic_game
            logic: _logic
            grid: _grid
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_game
            }
        }
    }

    Component {
        id: mouseLogic_temp_comp
        MouseLogic_Template {
            id: mouseLogic_temp
            logic: _logic
            grid: _grid
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_temp
            }
        }
    }


    Component {
        id: mouseLogic_selectionLink_comp
        MouseLogic_Selection_link {
            id: mouseLogic_selectionLink
            logic: _logic
            grid: _grid
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_selectionLink
            }
        }
    }


    Component{
        id: scrollLogic_normal_comp
        ScrollLogic {
            id: scrollLogic_normal
            editorGrid: _editorGrid
            logic: _logic
            Component.onCompleted: {
                logic.scrollLogic = scrollLogic_normal
            }
        }
    }

    Component{
        id: scrollLogic_pose_comp
        ScrollLogic_POSE {
            id: scrollLogic_pose
            editorGrid: _editorGrid
            logic: _logic
            Component.onCompleted: {
                logic.scrollLogic = scrollLogic_pose
            }
        }
    }


}

