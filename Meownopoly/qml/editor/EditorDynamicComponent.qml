import QtQuick 2.15
import TileType
import EditorEnum
import "logic"
import meowComponent

Item{
    id: editorDynamicComponent
    required property GridManager gameGrid
    required property var logic
    property alias snapableCaseTileComponent: snapableCaseTileComponent
    property alias snapableDecorationComponent: snapableDecorationComponent
    property alias snapablePhysicZoneComponent: snapablePhysicZoneComponent
    property alias snapableNPCComponent: snapableNPCComponent
    property alias snapableEnemyComponent: snapableEnemyComponent
    property alias mouseLogic_selection_comp: mouseLogic_selection_comp
    property alias mouseLogic_pose_comp: mouseLogic_pose_comp
    property alias mouseLogic_game_comp: mouseLogic_game_comp
    property alias mouseLogic_selectionLink_comp: mouseLogic_selectionLink_comp
    property alias mouseLogic_drawPolygon_comp: mouseLogic_drawPolygon_comp
    property alias mouseLogic_template_comp: mouseLogic_template_comp
    property alias scrollLogic_normal_comp: scrollLogic_normal_comp
    property alias scrollLogic_pose_comp: scrollLogic_pose_comp

    function _handleElementDeleted(element) {
        logic.tileLogic.deleteElementsConnections(element)
        element.connectionManager.deleteLinkedConnection()
        logic.tileLogic.deleteElement(element)
        if (logic.editorMouseMode === EditorEnum.EM_TEMPLATE)
            logic.mouseLogic.removeElementFromTemplateSelection(element)
    }

    Component {
        id: snapableCaseTileComponent
        SnapableCaseTile {
            gridManager: gameGrid
            displayLinkEnable: logic.tileLogic.displayLinkEnable === true
            onElementDeleted: editorDynamicComponent._handleElementDeleted(element)
        }
    }

    Component {
        id: snapableDecorationComponent
        SnapableDecoration {
            gridManager: gameGrid
            displayLinkEnable: logic.tileLogic.displayLinkEnable === true
            onElementDeleted: editorDynamicComponent._handleElementDeleted(element)
        }
    }

    Component {
        id: snapablePhysicZoneComponent
        SnapableExclusionZone {
            gridManager: gameGrid
            displayLinkEnable: logic.tileLogic.displayLinkEnable === true
            onElementDeleted: editorDynamicComponent._handleElementDeleted(element)
        }
    }

    Component {
        id: snapableNPCComponent
        SnapableNPC {
            gridManager: gameGrid
            displayLinkEnable: logic.tileLogic.displayLinkEnable === true
            onElementDeleted: editorDynamicComponent._handleElementDeleted(element)
        }
    }

    Component {
        id: snapableEnemyComponent
        SnapableEnemy {
            gridManager: gameGrid
            displayLinkEnable: logic.tileLogic.displayLinkEnable === true
            onElementDeleted: editorDynamicComponent._handleElementDeleted(element)
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

    Component {
        id: mouseLogic_drawPolygon_comp
        MouseLogic_DrawPolygon {
            id: mouseLogic_drawPolygon
            logic: _logic
            grid: _grid
            polygonPreviewComponent: _polygonPreview
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_drawPolygon
            }
        }
    }

    Component {
        id: mouseLogic_template_comp
        MouseLogic_Template {
            id: mouseLogic_template
            logic: _logic
            grid: _grid
            Component.onCompleted: {
                logic.mouseLogic = mouseLogic_template
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

