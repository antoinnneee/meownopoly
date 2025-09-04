import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager
import DecorationParameter


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
            decorationSettings: DecorationParameter {
                decorationCategory: root.assetCategory
                decorationType: root.assetType
                decorationId: root.assetId
            }
            parent: gridManager
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
        color: "#80000000"
        border.color: "#4A90E2"
        border.width: 2
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
