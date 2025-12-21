import QtQuick 2.15

MouseLogic_Base {
    id: mouseLogic
    property var targetEntity
    property var view3D
    property var editorGrid

    function pressedLeft(mouse, drag)
    {
        positionChanged(mouse, drag)
        targetEntity.visible = true
        // Map coordinates from MouseArea to View3D local coordinates
        // var pointInView = mainMa.mapToItem(view3D, mouse.x, mouse.y)

        // Calculate 3D position
        // var pos3D = getGroundIntersection(pointInView.x, pointInView.y)

        // Apply position
        // updateEntityPosition(pos3D)
    }

    function positionChanged(mouse, drag)
    {
        if (!view3D || !targetEntity) return

        // Map coordinates from MouseArea to View3D local coordinates
        var pointInView = mainMa.mapToItem(view3D, mouse.x, mouse.y)

        // Calculate 3D position
        //var pos3D = getGroundIntersection(pointInView.x, pointInView.y)
        
        // Apply position
        //updateEntityPosition(pos3D)
    }
    function updateEntityPosition(pos3D) {
        targetEntity.x = pos3D.x
        targetEntity.y = pos3D.y
        targetEntity.z = pos3D.z
    }

    Component.onCompleted: {
        targetEntity = logic.parent.entity
        view3D = logic.parent.view3D
        editorGrid = logic.editorGrid
    }
}
