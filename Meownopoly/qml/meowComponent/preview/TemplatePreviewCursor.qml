import QtQuick 2.15
import ItemSnapableFactory
import UiStyle
import "../snapable"
import "../grid"

Item {
    id: root
    
    x: mouseX
    y: mouseY
    z: UiStyle.z_TEMPLATE_PREVIEW
    
    required property GridManager gridManager
    property real mouseX: 0
    property real mouseY: 0
    property var templateData: null
    
    visible: templateData !== null && templateData.elements
    enabled: false
    
    property int gridXPosition: 0
    property int gridYPosition: 0
    
    // Calcul du centre du template pour le centrage
    property var boundingBox: calculateBoundingBox()
    property real centerOffsetX: boundingBox ? -boundingBox.centerX * gridManager.gridSize : 0
    property real centerOffsetY: boundingBox ? -boundingBox.centerY * gridManager.gridSize : 0
    
    onXChanged: updateGridPosition()
    onYChanged: updateGridPosition()
    onTemplateDataChanged: boundingBox = calculateBoundingBox()
    
    function calculateBoundingBox() {
        if (!templateData || !templateData.elements || templateData.elements.length === 0) {
            return null
        }
        
        var minX = Infinity, minY = Infinity
        var maxX = -Infinity, maxY = -Infinity
        
        for (var i = 0; i < templateData.elements.length; i++) {
            var elem = templateData.elements[i]
            var relX = elem.relativePositionX || 0
            var relY = elem.relativePositionY || 0
            var width = elem.displayParameter ? (elem.displayParameter.unitSizeWidth || 1) : 1
            var height = elem.displayParameter ? (elem.displayParameter.unitSizeHeight || 1) : 1
            
            minX = Math.min(minX, relX)
            minY = Math.min(minY, relY)
            maxX = Math.max(maxX, relX + width)
            maxY = Math.max(maxY, relY + height)
        }
        
        return {
            minX: minX,
            minY: minY,
            maxX: maxX,
            maxY: maxY,
            width: maxX - minX,
            height: maxY - minY,
            centerX: (minX + maxX) / 2,
            centerY: (minY + maxY) / 2
        }
    }
    
    function updateGridPosition() {
        var point = gridManager.getGridPosition(mouseX, mouseY)
        gridXPosition = point.x
        gridYPosition = point.y
    }
    
    Item {
        id: previewContainer
        parent: workArea
        x: gridXPosition * gridManager.gridSize + centerOffsetX
        y: gridYPosition * gridManager.gridSize + centerOffsetY
        
        Repeater {
            id: elementRepeater
            model: root.templateData && root.templateData.elements ? 
                   root.templateData.elements.length : 0
            
            delegate: Loader {
                id: elementLoader
                
                property var elementData: root.templateData.elements[index]
                property int relX: elementData ? (elementData.relativePositionX || 0) : 0
                property int relY: elementData ? (elementData.relativePositionY || 0) : 0
                
                x: relX * gridManager.gridSize
                y: relY * gridManager.gridSize
                
                sourceComponent: {
                    if (!elementData) return null
                    var tileType = elementData.tileType
                    if (tileType === 0) return casePreviewComp
                    if (tileType === 1) return decorationPreviewComp
                    if (tileType === 2) return zonePreviewComp
                    return null
                }
            }
        }
    }
    
    Component {
        id: decorationPreviewComp
        SnapableDecoration {
            property var elementData: parent && parent.elementData ? parent.elementData : null
            snapableParameters: ItemSnapableFactory.createItemSnapable()
            gridManager: root.gridManager
            opacity: 0.5
            z: UiStyle.z_TEMPLATE_PREVIEW + 1
            
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: "#4CAF50"
                border.width: 2
                radius: 4
            }
            
            Component.onCompleted: {
                if (!elementData) return
                if (elementData.displayParameter) {
                    snapableParameters.displayParameter.unitSizeWidth = elementData.displayParameter.unitSizeWidth || 1
                    snapableParameters.displayParameter.unitSizeHeight = elementData.displayParameter.unitSizeHeight || 1
                }
                if (elementData.decorationParameter) {
                    snapableParameters.decorationParameter.decorationCategory = elementData.decorationParameter.decorationCategory || ""
                    snapableParameters.decorationParameter.decorationType = elementData.decorationParameter.decorationType || ""
                    snapableParameters.decorationParameter.decorationId = elementData.decorationParameter.decorationId || ""
                }
            }
        }
    }
    
    Component {
        id: casePreviewComp
        SnapableCaseTile {
            property var elementData: parent && parent.elementData ? parent.elementData : null
            snapableParameters: ItemSnapableFactory.createItemSnapable(elementData && elementData.caseData ? elementData.caseData.type : 0)
            gridManager: root.gridManager
            opacity: 0.5
            z: UiStyle.z_TEMPLATE_PREVIEW + 1
            
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: "#4CAF50"
                border.width: 2
                radius: 4
            }
            
            Component.onCompleted: {
                if (!elementData || !elementData.displayParameter) return
                snapableParameters.displayParameter.unitSizeWidth = elementData.displayParameter.unitSizeWidth || 1
                snapableParameters.displayParameter.unitSizeHeight = elementData.displayParameter.unitSizeHeight || 1
            }
        }
    }
    
    Component {
        id: zonePreviewComp
        SnapableExclusionZone {
            property var elementData: parent && parent.elementData ? parent.elementData : null
            snapableParameters: ItemSnapableFactory.createPhysicZone()
            gridManager: root.gridManager
            opacity: 0.5
            z: UiStyle.z_TEMPLATE_PREVIEW + 1
            
            Component.onCompleted: {
                if (!elementData) return
                if (elementData.displayParameter) {
                    snapableParameters.displayParameter.gridRelativePositionX = 0
                    snapableParameters.displayParameter.gridRelativePositionY = 0
                    snapableParameters.displayParameter.unitSizeWidth = elementData.displayParameter.unitSizeWidth || 1
                    snapableParameters.displayParameter.unitSizeHeight = elementData.displayParameter.unitSizeHeight || 1
                }
                if (elementData.zoneParameter && elementData.zoneParameter.polygonPoints) {
                    var points = elementData.zoneParameter.polygonPoints
                    for (var i = 0; i < points.length; i++) {
                        snapableParameters.zoneParameter.addPoint(points[i].x, points[i].y)
                    }
                }
            }
        }
    }
}
