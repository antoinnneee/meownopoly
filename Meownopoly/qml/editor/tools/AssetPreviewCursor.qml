import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager
import DecorationParameter
import "../panel"


Item {
    id: root
    
    // Properties
    property string assetCategory: ""
    property string assetType: ""
    property string assetId: ""
    visible: assetCategory !== "" && assetType !== "" && assetId !== ""
    property real mouseX: 0
    property real mouseY: 0

    property int unitSizeWidth: 4
    property int unitSizeHeight: 6
    required property GridManager gridManager
    property var snapablePreview

    required property SelectionPanel selectionPanel
    Connections{
        target: selectionPanel.assetPanel.visualEffectsPanel
        function onEffectChanged(){
            var newTile = snapablePreview

            var visualEffectsPanel = selectionPanel.assetPanel.visualEffectsPanel
            if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return

            var currentEffects = visualEffectsPanel.getCurrentEffects()
            if (!currentEffects) return
            // Apply color effects
            newTile.displaySettings.effectBrightness = currentEffects.brightness
            newTile.displaySettings.effectContrast = currentEffects.contrast
            newTile.displaySettings.effectSaturation = currentEffects.saturation
            newTile.displaySettings.effectColorization = currentEffects.colorization
            newTile.displaySettings.effectColorizationColor = currentEffects.colorizationColor

            // Apply advanced effects
            newTile.displaySettings.effectBlurEnabled = currentEffects.blurEnabled
            newTile.displaySettings.effectBlur = currentEffects.blur
            newTile.displaySettings.effectShadowEnabled = currentEffects.shadowEnabled
            newTile.displaySettings.effectShadowBlur = currentEffects.shadowBlur

            // Apply transform effects
            newTile.displaySettings.rotationAngle = currentEffects.rotationAngle
            newTile.displaySettings.mirrorHorizontal = currentEffects.mirrorHorizontal
            newTile.displaySettings.mirrorVertical = currentEffects.mirrorVertical
        }
    }

    // Position the preview at mouse cursor
    x: mouseX - width / 2
    y: mouseY - height / 2

    property int gridXPosition:  0
    property int gridYPosition:  0
    onXChanged: {
        var point = gridManager.getGridPosition(mouseX, mouseY)
        gridXPosition = point.x
        if (snapablePreview) {
            snapablePreview.x = gridXPosition * gridManager.gridSize
        }
    }

    onYChanged: {
        var point = gridManager.getGridPosition(mouseX, mouseY)
        gridYPosition = point.y
        if (snapablePreview) {
            snapablePreview.y = gridYPosition * gridManager.gridSize
        }

    }

    width: 40
    height: 40
    z: 1000 // Make sure it's on top
    
    // Make it non-interactive
    enabled: false
    Component {
        id: assetPreviewComponent
        SnapableDecoration {
            id: snapableDecoration
            Rectangle{
                color: "transparent"
                border.color: "black"
                anchors.fill: parent
                border.width: 3
                radius: 4
            }

            decorationSettings: DecorationParameter {
                decorationCategory: root.assetCategory
                decorationType: root.assetType
                decorationId: root.assetId
            }
            parent: workArea
            visible: root.visible
            x:gridXPosition * gridManager.gridSize
            y:gridYPosition * gridManager.gridSize
            displaySettings.unitSizeWidth: root.unitSizeWidth
            displaySettings.unitSizeHeight: root.unitSizeHeight
            gridManager: root.gridManager
            Component.onCompleted: {
                root.snapablePreview = snapableDecoration
            }
        }
    }

    Loader {
        id: assetPreviewLoader
        sourceComponent: assetPreviewComponent
    }
    
    Rectangle {
        anchors.fill: parent
        color: "#A0000000"
        border.color: "#4A90E2"
        border.width: 4
        radius: 4
        visible: root.visible
        
        Image {
            anchors.centerIn: parent
            width: parent.width - 8
            height: parent.height - 8
            source: {
                if (root.assetCategory === "" || root.assetType === "" || root.assetId === "") {
                    return ""
                }
                return AssetManager.getAssetPath(root.assetCategory, root.assetType, root.assetId)
            }
            fillMode: Image.PreserveAspectFit
            smooth: true
            opacity: 0.8
        }
        
        // Small indicator showing it's ready to place
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: -2
            width: 12
            height: 12
            color: "#4CAF50"
            radius: 6
            
            Text {
                anchors.centerIn: parent
                text: "+"
                color: "white"
                font.pixelSize: 8
                font.bold: true
            }
        }
    }
}
