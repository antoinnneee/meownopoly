import QtQuick 2.15
import QtQuick.Controls 2.15


Item {
    id: control
    property int maxLayer: 10
    property int selectedLayer: 0
    property int spacing: Screen.pixelDensity * 2
    property int layerHeight :  Screen.pixelDensity * 4

    height: 10

    signal layerClicked(var index)

    Repeater{
        model:maxLayer
        Rectangle {
            id: rectangle
            required property int index
            x: (selectedLayer == index)?width/4 : 0
            y: spacing*index
            width: control.width * 0.75
            height: layerHeight
            color: "#cd7a81ab"
            radius: 10
            border.width: 1
            Behavior on x { NumberAnimation { duration: 150 ; easing.type: Easing.InOutQuad} }
            MouseArea{
                anchors.fill: parent
                onClicked: {
                    layerClicked(parent.index)
                }
            }
            Component.onCompleted: {
                control.height = rectangle.height + rectangle.y
            }
        }

    }


}
