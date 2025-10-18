import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager
import DecorationParameter
import "../panel"
import Game
import ItemSnapable
import ItemSnapableFactory

Item {
    id: root
    
    // Properties
    property string assetCategory: ""
    onAssetCategoryChanged: {
        snapablePreview.snapableParameters.decorationParameter.decorationCategory = assetCategory
    }

    property string assetType: ""
    onAssetTypeChanged: {
        snapablePreview.snapableParameters.decorationParameter.decorationType = assetType
    }
    property string assetId: ""
    onAssetIdChanged: {
        snapablePreview.snapableParameters.decorationParameter.decorationId = assetId
    }
    property int caseType: -1  // Pour les SnapableCaseTile
    property bool isCasePreview: false  // Distingue entre décorations et cases
    visible: (assetCategory !== "" && assetType !== "" && assetId !== "") || (isCasePreview && caseType !== -1)
    property real mouseX: 0
    property real mouseY: 0

    property int unitSizeWidth: 4
    property int unitSizeHeight: 6
    required property GridManager gridManager
    property var snapablePreview

    required property SelectionPanel selectionPanel

    
    // Fonction pour obtenir l'icône selon le type de case
    function getCaseTypeIcon(caseType) {
        return ""
        switch(caseType) {
            case 0: return "qrc:/assets/icons/kibble_dispenser.png"  // CS_KibbleDispenser
            case 1: return "qrc:/assets/icons/rest_area.png"         // CS_RestArea
            case 2: return "qrc:/assets/icons/cardboard_box.png"     // CS_CardBoardBox
            case 3: return "qrc:/assets/icons/cat_nip.png"           // CS_CatNip
            case 4: return "qrc:/assets/icons/jail.png"              // CS_Jail
            case 5: return "qrc:/assets/icons/to_jail.png"           // CS_ToJail
            case 6: return "qrc:/assets/icons/cat_door.png"          // CS_CatDoor
            case 7: return "qrc:/assets/icons/free_nap.png"          // CS_FreeNap
            case 8: return "qrc:/assets/icons/device.png"            // CS_Device
            case 9: return "qrc:/assets/icons/taxe.png"              // CS_Taxe
            default: return "qrc:/assets/icons/unknown_case.png"
        }
    }
    
    Connections{
        target: selectionPanel.assetPanel.visualEffectsPanel
        function onEffectChanged(){
            var newTile = snapablePreview

            var visualEffectsPanel = selectionPanel.assetPanel.visualEffectsPanel
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

    // Position the preview at mouse cursor
    x: mouseX - width / 2
    y: mouseY - height / 2

    property int gridXPosition:  0
    property int gridYPosition:  0
    onXChanged: {
        var point = gridManager.getGridPosition(mouseX, mouseY)
        gridXPosition = point.x - Math.trunc(logic.tileLogic.currentElementWidth/2)
        if (snapablePreview) {
            snapablePreview.x = gridXPosition * gridManager.gridSize
        }
    }

    onYChanged: {
        var point = gridManager.getGridPosition(mouseX, mouseY)
        gridYPosition = point.y - Math.trunc(logic.tileLogic.currentElementHeight/2)
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
        id: decorationPreviewComponent
        SnapableDecoration {
            id: snapableDecoration
            Rectangle{
                color: "transparent"
                border.color: "black"
                anchors.fill: parent
                border.width: 1
                radius: 4
                opacity: 0.2
            }



            snapableParameters : ItemSnapableFactory.createItemSnapable()



            parent: workArea
            visible: root.visible
            x:gridXPosition * gridManager.gridSize
            y:gridYPosition * gridManager.gridSize
            //displaySettings.unitSizeWidth: root.unitSizeWidth
            //displaySettings.unitSizeHeight: root.unitSizeHeight
            z: 5.01
            gridManager: root.gridManager
            Component.onCompleted: {
                console.log("preview load complete")
                root.snapablePreview = snapableDecoration

                snapableParameters.decorationParameter.decorationCategory = root.assetCategory
                snapableParameters.decorationParameter.decorationType = root.assetType
                snapableParameters.decorationParameter.decorationId = root.assetId
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
                radius: 4
                opacity: 0.2
            }

            snapableParameters : ItemSnapableFactory.createItemSnapable(caseType)

            parent: workArea
            visible: root.visible
            x:gridXPosition * gridManager.gridSize
            y:gridYPosition * gridManager.gridSize
            //displaySettings.unitSizeWidth: root.unitSizeWidth
            //displaySettings.unitSizeHeight: root.unitSizeHeight
            z: 5.01
            gridManager: root.gridManager
            Component.onCompleted: {
                console.log("preview load complete")
                root.snapablePreview = snapableCaseTile
            }
        }
    }

    Loader {
        id: assetPreviewLoader
        sourceComponent: root.isCasePreview ? casePreviewComponent : decorationPreviewComponent
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
                if (root.isCasePreview) {
                    // Pour les cases, on peut utiliser une icône par défaut ou une icône basée sur le type de case
                    return getCaseTypeIcon(root.caseType)
                } else {
                    if (root.assetCategory === "" || root.assetType === "" || root.assetId === "") {
                        return ""
                    }
                    return AssetManager.getAssetPath(root.assetCategory, root.assetType, root.assetId)
                }
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
