import QtQuick 2.15
import QtQuick.Controls 2.15


Item {
    id: control
    property int maxLayer: 10
    property int selectedLayer: 0
    property int spacing: Screen.pixelDensity * 1.5
    property int layerHeight :  Screen.pixelDensity * 3

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
            radius: 5
            border.width: 1
            Behavior on x { NumberAnimation { duration: 150 ; easing.type: Easing.InOutQuad} }
            
            Component.onCompleted: {
                control.height = rectangle.height + rectangle.y
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        
        function getLayerAtPosition(mouseY) {
            // Parcourir tous les rectangles pour trouver celui sous la souris
            for (var i = 0; i < maxLayer; i++) {
                var rectY = spacing * i
                var rectHeight = layerHeight
                
                // Vérifier si la souris est dans les limites de ce rectangle
                if (mouseY >= rectY && mouseY <= rectY + rectHeight) {
                    return i
                }
            }
            
            // Si aucun rectangle trouvé, retourner le plus proche
            if (mouseY < 0) return 0
            if (mouseY > spacing * (maxLayer - 1) + layerHeight) return maxLayer - 1
            
            // Fallback: calculer le plus proche
            return Math.round(mouseY / (spacing + layerHeight / 2))
        }
        
        onPressed: function(mouse) {
            var layerIndex = getLayerAtPosition(mouse.y)
            layerIndex = Math.max(0, Math.min(maxLayer - 1, layerIndex))
            layerClicked(layerIndex)
        }
        
        onPositionChanged: function(mouse) {
            if (pressed) {
                var layerIndex = getLayerAtPosition(mouse.y)
                layerIndex = Math.max(0, Math.min(maxLayer - 1, layerIndex))
                layerClicked(layerIndex)
            }
        }
    }


}

