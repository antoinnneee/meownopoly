import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager
import DecorationParameter

import editor
import meowComponent
import theme

import Game
import ItemSnapable
import ItemSnapableFactory

Item {
    id: root

    // Postion the preview at mouse cursor
    x: mouseX - width / 2
    y: mouseY - height / 2


    width: 40
    height: 40
    z: 1000 // Make sure it's on top

    required property GridManager gridManager
    required property BottomSidePanel sidePanel

    property var snapablePreview


    property string assetCategory: ""
    property string assetType: ""
    property string assetId: ""

    property int caseType: -1  // Pour les SnapableCaseTile

    property bool isCasePreview: false  // Distingue entre décorations et cases

    property real mouseX: 0
    property real mouseY: 0

    property int unitSizeWidth: 4
    property int unitSizeHeight: 6

    visible: (assetCategory !== "" && assetType !== "" && assetId !== "") || (isCasePreview && caseType !== -1)


    // Properties
    onAssetCategoryChanged: {
        snapablePreview.snapableParameters.decorationParameter.decorationCategory = assetCategory
    }

    onAssetTypeChanged: {
        snapablePreview.snapableParameters.decorationParameter.decorationType = assetType
    }
    onAssetIdChanged: {
        snapablePreview.snapableParameters.decorationParameter.decorationId = assetId
    }
    onCaseTypeChanged: {
        if ( snapablePreview.snapableParameters != caseType)
            snapablePreview.snapableParameters = ItemSnapableFactory.createItemSnapable(caseType)
        snapablePreview.snapableParameters.displayParameter.unitSizeWidth = root.unitSizeWidth
        snapablePreview.snapableParameters.displayParameter.unitSizeHeight = root.unitSizeHeight
    }


    onUnitSizeWidthChanged: {
        if (typeof snapablePreview !== 'undefined'){
            snapablePreview.snapableParameters.displayParameter.unitSizeWidth = unitSizeWidth
            updateGridPosition()
        }
    }

    onUnitSizeHeightChanged: {
        if (typeof snapablePreview !== 'undefined'){
            snapablePreview.snapableParameters.displayParameter.unitSizeHeight = unitSizeHeight
            updateGridPosition()
        }
    }

    Connections{
        target: sidePanel.visualEffectsPanel
        function onEffectChanged(){
            var newTile = snapablePreview

            var visualEffectsPanel = sidePanel.visualEffectsPanel
            if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return

            var currentEffects = visualEffectsPanel.getCurrentEffects()
            if (!currentEffects) return
            // Apply color effects
            newTile.snapableParameters.displayParameter.effectBrightness = currentEffects.brightness
            newTile.snapableParameters.displayParameter.effectContrast = currentEffects.contrast
            newTile.snapableParameters.displayParameter.effectSaturation = currentEffects.saturation
            newTile.snapableParameters.displayParameter.effectColorization = currentEffects.colorization
            newTile.snapableParameters.displayParameter.effectColorizationColor = currentEffects.colorizationColor

            // Apply advanced effects
            newTile.snapableParameters.displayParameter.effectBlurEnabled = currentEffects.blurEnabled
            newTile.snapableParameters.displayParameter.effectBlur = currentEffects.blur
            newTile.snapableParameters.displayParameter.effectShadowEnabled = currentEffects.shadowEnabled
            newTile.snapableParameters.displayParameter.effectShadowBlur = currentEffects.shadowBlur

            // Apply transform effects
            newTile.snapableParameters.displayParameter.rotationAngle = currentEffects.rotationAngle
            newTile.snapableParameters.displayParameter.mirrorHorizontal = currentEffects.mirrorHorizontal
            newTile.snapableParameters.displayParameter.mirrorVertical = currentEffects.mirrorVertical
        }
    }


    property int gridXPosition:  0
    property int gridYPosition:  0
    onXChanged: {
        updateGridPosition()
    }

    onYChanged: {
        updateGridPosition()
    }
    function updateGridPosition()
    {
        var point = gridManager.getGridPosition(mouseX, mouseY)
        gridYPosition = point.y - Math.trunc(logic.tileLogic.currentElementHeight/2)
        gridXPosition = point.x - Math.trunc(logic.tileLogic.currentElementWidth/2)
        if (snapablePreview) {
            snapablePreview.y = gridYPosition * gridManager.gridSize
            snapablePreview.x = gridXPosition * gridManager.gridSize
        }
    }


    // Make it non-interactive
    enabled: false
    // Bind la zOrder des previews sur la valeur que tickLamport() retournera
    // au prochain clic de pose : la preview se rend à la z-height exacte qu'aura
    // la tile placée (z = zOrder + zLayer via le binding de SnapableElement).
    // Sans ça, le z hardcodé restait derrière les tuiles à zOrder élevé.
    Binding {
        when: root.snapablePreview !== undefined && root.snapablePreview !== null
        target: root.snapablePreview ? root.snapablePreview.snapableParameters.displayParameter : null
        property: "zOrder"
        value: Game.previewZOrder
    }

    Component {
        id: decorationPreviewComponent
        SnapableDecoration {
            id: snapableDecoration
            Rectangle{
                color: "transparent"
                border.color: "black"
                anchors.fill: parent
                border.width: 1
                radius: Theme.radiusS
                opacity: 0.2
            }

            snapableParameters: ItemSnapableFactory.createItemSnapable()

            parent: workArea
            visible: root.visible
            x:gridXPosition * gridManager.gridSize
            y:gridYPosition * gridManager.gridSize
            // z hérité de SnapableElement : zOrder + zLayer. zOrder est bindé
            // au-dessus sur Game.previewZOrder → matche la future placement z.
            gridManager: root.gridManager
            Component.onCompleted: {
                root.snapablePreview = snapableDecoration

                snapableParameters.decorationParameter.decorationCategory = root.assetCategory
                snapableParameters.decorationParameter.decorationType = root.assetType
                snapableParameters.decorationParameter.decorationId = root.assetId
                snapableParameters.displayParameter.unitSizeWidth = root.unitSizeWidth
                snapableParameters.displayParameter.unitSizeHeight = root.unitSizeHeight
            }
        }
    }

    Component {
        id: casePreviewComponent
        SnapableCaseTile {
            id: snapableCaseTile
            Rectangle{
                color: "transparent"
                border.color: "black"
                anchors.fill: parent
                border.width: 1
                radius: Theme.radiusS
                opacity: 0.2
            }

            snapableParameters : ItemSnapableFactory.createItemSnapable(root.caseType)

            parent: workArea
            visible: root.visible
            x:gridXPosition * gridManager.gridSize
            y:gridYPosition * gridManager.gridSize
            // z hérité de SnapableElement (zOrder bindé sur Game.previewZOrder)
            gridManager: root.gridManager
            Component.onCompleted: {
                root.snapablePreview = snapableCaseTile
                if (snapableParameters.caseData.type != root.caseType)
                    snapableParameters = ItemSnapableFactory.createItemSnapable(root.caseType)
                snapableParameters.displayParameter.unitSizeWidth = root.unitSizeWidth
                snapableParameters.displayParameter.unitSizeHeight = root.unitSizeHeight
            }
        }
    }

    Loader {
        id: assetPreviewLoader
        sourceComponent: root.isCasePreview ? casePreviewComponent : decorationPreviewComponent
    }

}
