import QtQuick 2.15
import UiStyle
import EditorEnum
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

    // MouseArea to track cursor position for template preview
    MouseArea {
        id: templateTracker
        z: 51
        parent: workArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: logic.editorMouseMode === EditorEnum.EM_TEMPLATE
        acceptedButtons: Qt.NoButton // Don't interfere with clicks
        propagateComposedEvents: true
        preventStealing: true

        onPositionChanged: function(mouse) {
            templatePreview.mouseX = mouse.x
            templatePreview.mouseY = mouse.y
        }
    }
}
