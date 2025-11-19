import QtQuick 2.15

MouseLogic_Base {
    id: mouseLogic
    property var targetEntity
    function pressedLeft(mouse, drag)
    {
        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        targetEntity.visible = true
        targetEntity.x = workAreaPos.x
        targetEntity.y = workAreaPos.y
    }

    function positionChanged(mouse, drag)
    {
        var workAreaPos = mainMa.mapToItem(workArea, mouse.x, mouse.y)
        console.log("positionChanged", workAreaPos.x, workAreaPos.y)
        targetEntity.x = workAreaPos.x
        targetEntity.y = workAreaPos.y

    }

    Component.onCompleted: {
        targetEntity = logic.parent.entity
    }
}
