import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager

Item {
    id: root
    
    // Properties
    property string assetCategory: ""
    property string assetType: ""
    property string assetId: ""
    visible: assetCategory !== "" && assetType !== "" && assetId !== ""
    property real mouseX: 0
    property real mouseY: 0
    
    // Position the preview at mouse cursor
    x: mouseX - width / 2
    y: mouseY - height / 2
    width: 40
    height: 40
    z: 1000 // Make sure it's on top
    
    // Make it non-interactive
    enabled: false
    
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
                if (root.assetCategory === "decoration") {
                    return AssetManager.getDecorationPath(root.assetType, root.assetId)
                } else if (root.assetCategory === "tile") {
                    return AssetManager.getTilePath(root.assetType, root.assetId)
                } else if (root.assetCategory === "avatar") {
                    return AssetManager.getPlayerIconPath(root.assetId)
                }
                return ""
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
