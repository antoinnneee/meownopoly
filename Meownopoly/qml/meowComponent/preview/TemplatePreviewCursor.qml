import QtQuick 2.15
import ItemSnapableFactory
import UiStyle
import "../snapable"
import "../grid"

Item {
    id: root

    x: mouseX - width / 2
    y: mouseY - height / 2

    width: 40
    height: 40

    z: UiStyle.z_TEMPLATE_PREVIEW

    required property GridManager gridManager
    property real mouseX: 0
    property real mouseY: 0
    property var templateData: null

    property var snapablePreview
    
    visible: templateData !== null && templateData.elements
    enabled: false

    onVisibleChanged: {
        console.log("[TemplatePreviewCursor] visible=" + visible
                    + " templateData=" + (templateData ? "set" : "null")
                    + " elements=" + (templateData && templateData.elements
                                        ? templateData.elements.length : "N/A")
                    + " mouseX=" + mouseX + " mouseY=" + mouseY)
    }
    
    property int gridXPosition: 0
    property int gridYPosition: 0
    
    // Calcul du centre du template pour le centrage
    property var boundingBox: calculateBoundingBox()
    property real centerOffsetX: boundingBox ? -boundingBox.centerX * gridManager.gridSize : 0
    property real centerOffsetY: boundingBox ? -boundingBox.centerY * gridManager.gridSize : 0
    
    onXChanged: updateGridPosition()
    onYChanged: updateGridPosition()
    onTemplateDataChanged: boundingBox = calculateBoundingBox()

    function copyDisplayParameterFromTemplateData(snapableDest, templateData) {
        if (templateData.displayParameter) {
            snapableDest.displayParameter.unitSizeWidth = templateData.displayParameter.unitSizeWidth || 1
            snapableDest.displayParameter.unitSizeHeight = templateData.displayParameter.unitSizeHeight || 1
            snapableDest.displayParameter.gridRelativePositionX = templateData.displayParameter.gridRelativePositionX
            snapableDest.displayParameter.gridRelativePositionY = templateData.displayParameter.gridRelativePositionY
            snapableDest.displayParameter.effectBrightness = templateData.displayParameter.effectBrightness || 0
            snapableDest.displayParameter.effectContrast = templateData.displayParameter.effectContrast || 0
            snapableDest.displayParameter.effectSaturation = templateData.displayParameter.effectSaturation || 0
            snapableDest.displayParameter.effectColorization = templateData.displayParameter.effectColorization || 0
            snapableDest.displayParameter.effectColorizationColor = templateData.displayParameter.effectColorizationColor || "white"
            snapableDest.displayParameter.effectBlurEnabled = templateData.displayParameter.effectBlurEnabled || false
            snapableDest.displayParameter.effectBlur = templateData.displayParameter.effectBlur || 0
            snapableDest.displayParameter.effectBlurMax = templateData.displayParameter.effectBlurMax || 32
            snapableDest.displayParameter.effectBlurMultiplier = templateData.displayParameter.effectBlurMultiplier || 1
            snapableDest.displayParameter.effectShadowEnabled = templateData.displayParameter.effectShadowEnabled || false
            snapableDest.displayParameter.effectShadowBlur = templateData.displayParameter.effectShadowBlur || 1
            snapableDest.displayParameter.effectShadowColor = templateData.displayParameter.effectShadowColor || "black"
            snapableDest.displayParameter.effectShadowHorizontalOffset = templateData.displayParameter.effectShadowHorizontalOffset || 0
            snapableDest.displayParameter.effectShadowVerticalOffset = templateData.displayParameter.effectShadowVerticalOffset || 0
            snapableDest.displayParameter.effectShadowOpacity = templateData.displayParameter.effectShadowOpacity || 1
            snapableDest.displayParameter.effectShadowScale = templateData.displayParameter.effectShadowScale || 1
            snapableDest.displayParameter.rotationAngle = templateData.displayParameter.rotationAngle || 0
            snapableDest.displayParameter.mirrorHorizontal = templateData.displayParameter.mirrorHorizontal || false
            snapableDest.displayParameter.mirrorVertical = templateData.displayParameter.mirrorVertical || false

            snapableDest.displayParameter.gridRelativePositionX = templateData.relativePositionX
            snapableDest.displayParameter.gridRelativePositionY = templateData.relativePositionY
        }
        if (templateData.decorationParameter) { 
            snapableDest.decorationParameter.decorationCategory = templateData.decorationParameter.decorationCategory || ""
            snapableDest.decorationParameter.decorationType = templateData.decorationParameter.decorationType || ""
            snapableDest.decorationParameter.decorationId = templateData.decorationParameter.decorationId || ""
        }

        if (templateData.zoneParameter) {
            var zp = templateData.zoneParameter
            if (zp.zoneColor !== undefined) snapableDest.zoneParameter.zoneColor = zp.zoneColor
            if (zp.zoneName !== undefined) snapableDest.zoneParameter.zoneName = zp.zoneName
            if (zp.polygonPoints) {
                var points = zp.polygonPoints
                for (var i = 0; i < points.length; i++) {
                    snapableDest.zoneParameter.addPoint(points[i].x, points[i].y)
                }
            }
        }
    }
    
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
        // Convertir (mouseX, mouseY) de workArea vers la grille pour un getGridPosition cohérent
        var p = gridManager.mapFromItem(root.parent, mouseX, mouseY)
        var point = gridManager.getGridPosition(p.x, p.y)
        gridXPosition = templateData ? point.x - Math.trunc(templateData.templateInfo.boundingBoxWidth/2) : 0
        gridYPosition = templateData ? point.y - Math.trunc(templateData.templateInfo.boundingBoxHeight/2) : 0
        previewContainer.x = gridXPosition * gridManager.gridSize
        previewContainer.y = gridYPosition * gridManager.gridSize
    }
    
    Item {
        id: previewContainer
        parent: workArea
        Rectangle{
            anchors.fill: parent
            color: "red"
            border.color: "red"
            border.width: 3
            radius: 4
        }
        Repeater {
            id: elementRepeater
            model: root.templateData && root.templateData.elements ? 
                   root.templateData.elements.length : 0
            
            delegate: Loader {
                id: elementLoader
                
                property int elementIndex: index
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
            id: snapableDecoration
            property var elementData: parent && parent.elementData ? parent.elementData : null
            property int elementIndex: parent && parent.elementIndex !== undefined ? parent.elementIndex : -1
            snapableParameters: ItemSnapableFactory.createItemSnapable()
            gridManager: root.gridManager
            opacity: 0.5
            z: UiStyle.z_TEMPLATE_PREVIEW + 1
            Component.onCompleted: {
                if (!elementData) return
                copyDisplayParameterFromTemplateData(snapableParameters, elementData)
            }
        }
    }
    
    Component {
        id: casePreviewComp
        SnapableCaseTile {
            id: snapableCaseTile
            property var elementData: parent && parent.elementData ? parent.elementData : null
            property int elementIndex: parent && parent.elementIndex !== undefined ? parent.elementIndex : -1
            snapableParameters: ItemSnapableFactory.createItemSnapable(elementData && elementData.caseData ? elementData.caseData.type : 0)
            gridManager: root.gridManager
            opacity: 0.5
            z: UiStyle.z_TEMPLATE_PREVIEW + 1

            
            Component.onCompleted: {
                if (!elementData || !elementData.displayParameter) return
                copyDisplayParameterFromTemplateData(snapableParameters, elementData)
            }
        }
    }
    
    Component {
        id: zonePreviewComp
        SnapableExclusionZone {
            id: snapableExclusion
            property var elementData: parent && parent.elementData ? parent.elementData : null
            property int elementIndex: parent && parent.elementIndex !== undefined ? parent.elementIndex : -1
            snapableParameters: ItemSnapableFactory.createPhysicZone()
            gridManager: root.gridManager
            // Le preview n'est pas dans snapableTilesList → ZonesOverlayPainter
            // global ne le voit pas. Forcer le rendu via le ZoneCanvasPainter local.
            forceLocalRenderer: true
            opacity: 0.5
            z: UiStyle.z_TEMPLATE_PREVIEW + 1

            Component.onCompleted: {
                if (!elementData) return
                copyDisplayParameterFromTemplateData(snapableParameters, elementData)
            }
        }
    }
}
