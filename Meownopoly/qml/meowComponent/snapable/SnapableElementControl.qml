import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import ui_item

import MapTypes
import EditorOpBus 1.0

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

    // Taille dictée par le badge compact (cible tactile ~9 mm)
    anchors.leftMargin: 10
    width: controlsColumn.width
    height: controlsColumn.height

    Column {
        id: controlsColumn
        spacing: 5

        LayerVisualizer {
            id: layerOption
            selectedLayer: controlsRoot.zLayer - 1

            onLayerClicked: function(index) {
                controlsRoot.layerChanged(index + 1)
                // SetDisplayParameter{zLayer} (log-only).
                if (controlsRoot.targetElement && controlsRoot.targetElement.snapableParameters) {
                    EditorOpBus.recordOp({
                        "op":     EditorOpType.SetDisplayParameter,
                        "target": String(controlsRoot.targetElement.snapableParameters.uniqueId),
                        "fields": { "zLayer": index + 1 }
                    })
                }
                logic.saveMap(MapTypes.UNDOREDO)
            }

            Behavior on scale {
                NumberAnimation { duration: 100 }
            }
        }
    }
}
