import QtQuick 2.15
import UiStyle
import EditorEnum
import meowComponent

Item {

    // MouseArea to track cursor position for asset preview
    MouseArea {
        id: cursorTracker
        parent: workArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: logic.editorMouseMode === EditorEnum.EM_POSE
        acceptedButtons: Qt.NoButton // Don't interfere with clicks
        propagateComposedEvents: true
        preventStealing: true
        z: 50

        onPositionChanged: function(mouse) {
            assetPreview.mouseX = mouse.x
            assetPreview.mouseY = mouse.y
        }
    }


    // MouseArea to track cursor position for link preview
    MouseArea {
        id: linkTracker
        z: UiStyle.z_LINK_TRACKER
        parent: workArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK
        acceptedButtons: Qt.NoButton // Don't interfere with clicks
        propagateComposedEvents: true
        preventStealing: true


        onPositionChanged: function(mouse) {
            if (logic.mouseLogic && logic.mouseLogic.updateMousePosition) {
                logic.mouseLogic.updateMousePosition(mouse.x, mouse.y)
            }
        }
    }

    // MouseArea to track cursor position for template placement preview
    MouseArea {
        id: templatePlacementTracker
        parent: workArea
        anchors.fill: parent
        hoverEnabled: true

        enabled: logic.editorMouseMode !== undefined &&
                 logic.editorMouseMode === EditorEnum.EM_TEMPLATE &&
                 logic.mouseLogic !== undefined &&
                 logic.mouseLogic.isPlacementMode === true

        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true
        preventStealing: true
        z: 50

        onPositionChanged: function(mouse) {
            // templatePreview.mouseX/mouseY sont liés à mouseLogic.previewMouseX/Y
            // via binding déclarative dans Editor.qml — une seule écriture suffit.
            if (logic.mouseLogic) {
                logic.mouseLogic.previewMouseX = mouse.x
                logic.mouseLogic.previewMouseY = mouse.y
            }
        }
    }

    // ==================== TEMPLATE MODE TRACKER ====================
    
    // Repeater pour afficher les rectangles verts de sélection template
    Repeater {
        id: templateBoundingBoxRepeater
        
        // Modèle : liste des bounding boxes depuis MouseLogic_Template
        model: (logic.editorMouseMode === EditorEnum.EM_TEMPLATE && logic.mouseLogic && logic.mouseLogic.templateBoundingBoxes)
               ? logic.mouseLogic.templateBoundingBoxes
               : []
        
        delegate: TemplateBoundingRect {
            parent: workArea
            boundingData: modelData
            z: UiStyle.z_SELECTION_RECT + 1
        }
    }
}
