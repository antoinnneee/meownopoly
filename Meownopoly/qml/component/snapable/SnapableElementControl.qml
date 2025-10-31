import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import "../../ui_item"

import MapTypes

Item {
    id: controlsRoot
    
    // Propriétés requises du parent
    required property var targetElement
    required property bool isVisible
    required property int zLayer
    
    // Signaux
    signal layerChanged(int newLayer)

    // Propriété pour accéder à la valeur z du target
    readonly property int currentZ: targetElement ? targetElement.z : 0

    visible: isVisible
    z: 200  // Au-dessus de tout
    
    // Positionner à droite de l'élément parent
    anchors.left: parent.right
    anchors.top: parent.top
    anchors.leftMargin: 10
    width: 40
    height: controlsColumn.height
    
    // Colonne de contrôles
    Column {
        id: controlsColumn
        spacing: 5
        
        // Sélecteur de plans
        Column {
            id: layerSelector
            spacing: 2
            width: 40

            LayerVisualizer {
                id: layerOption
                width: parent.width
                selectedLayer: zLayer -1
                onLayerClicked: function(index){
                    console.log("layer " + index + "clicked")
                    layerChanged(index +1)
                    logic.saveMap(MapTypes.UNDOREDO)
                }

                Behavior on scale {
                    NumberAnimation { duration: 100 }
                }

            }
        }

    }
}
