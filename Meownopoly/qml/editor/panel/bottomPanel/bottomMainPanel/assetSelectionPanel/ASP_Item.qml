import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    
    // Properties
    property string assetPath: ""
    property string assetId: ""
    property string assetFilename: ""
    property int assetWidth: 0
    property int assetHeight: 0
    property int assetRatioWidth: 1
    property int assetRatioHeight: 1
    property bool isSelected: false
    property bool isFavorite: false
    property string assetDescription: ""
    
    // Signals
    signal assetClicked(string id)
    
    // Visual properties
    width: 80
    height: 80
    color: {
        if (isSelected) return "#4A90E2"
        if (mouseArea.containsMouse) return "#555555"
        return "#444444"
    }
    border.color: isSelected ? "#6BB6FF" : "#666666"
    border.width: isSelected ? 2 : 1
    radius: 6
    
    Behavior on color {
        ColorAnimation { duration: 150 }
    }
    
    Behavior on border.width {
        NumberAnimation { duration: 150 }
    }
    
    // Main content
    Column {
        anchors.fill: parent
        anchors.margins: 2
        spacing: -1


        // Image preview
        Rectangle {
            id: assetPreview
            width: parent.width
            height: parent.height - assetInfo.implicitHeight
            color: "transparent"
            clip: true
            
            Image {
                id: previewImage
                anchors.centerIn: parent
                width: Math.min(parent.width - 2, sourceSize.width)
                height: Math.min(parent.height - 2, sourceSize.height)
                source: root.assetPath
                fillMode: Image.PreserveAspectFit
                smooth: true
                asynchronous: true
                
                // Loading placeholder
                Rectangle {
                    anchors.fill: parent
                    color: "#333333"
                    visible: parent.status === Image.Loading
                    
                    BusyIndicator {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        running: parent.visible
                    }
                }
                
                // Favorite indicator
                Rectangle {
                    id: favoriteIndicator
                    anchors.top: parent.top
                    anchors.right: parent.right
                    width: favoriteText.implicitWidth / 2
                    height: favoriteText.implicitHeight / 2
                    radius: 8
                    visible:true
                    color: "transparent"
                    
                    Text {
                        id: favoriteText
                        anchors.centerIn: parent
                        color: '#ffc400'
                        text: root.isFavorite ? "★" : "☆"
                        font.pointSize: 13
                    }
                }
            }
        }
        // Asset ID/Name
        Text {
            id: assetInfo
            width: parent.width

            text: root.assetId || root.assetFilename
            color: "white"
            font.pointSize: 8
            font.bold: true
            elide: Text.ElideMiddle
            horizontalAlignment: Text.AlignHCenter
        }
    }
    
    // Mouse interaction
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        
        onClicked: function(mouse) {
            if (mouse.button === Qt.LeftButton) {
                root.assetClicked(root.assetId)
            }
        }
    }
    MouseArea {
        x: favoriteIndicator.x
        y: favoriteIndicator.y
        width: favoriteText.implicitWidth
        height: favoriteText.implicitHeight
        onClicked: {
            root.isFavorite = !root.isFavorite
        }
        z:10
    }

    // Hover effect
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#4A90E2"
        border.width: mouseArea.containsMouse && !root.isSelected ? 1 : 0
        radius: 6
        
        Behavior on border.width {
            NumberAnimation { duration: 150 }
        }
    }
    
    // Selection highlight
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.color: "#6BB6FF"
        border.width: root.isSelected ? 3 : 0
        radius: 6
        opacity: 0.8
        
        Behavior on border.width {
            NumberAnimation { duration: 200 }
        }
    }
    
    // Tooltip on hover
    ToolTip {
        visible: mouseArea.containsMouse
        delay: 500
        timeout: 3000
        
        contentItem: Column {
            spacing: 4
            
            Text {
                text: "ID: " + root.assetId
                color: "white"
                font.pixelSize: 11
                font.bold: true
            }
            
            Text {
                text: "File: " + root.assetFilename
                color: "#CCCCCC"
                font.pixelSize: 10
            }
            
            Text {
                text: "Size: " + root.assetWidth + "×" + root.assetHeight + " px"
                color: "#CCCCCC"
                font.pixelSize: 10
                visible: root.assetWidth > 0 && root.assetHeight > 0
            }
            
            Text {
                text: "Ratio: " + root.assetRatioWidth + ":" + root.assetRatioHeight
                color: "#CCCCCC"
                font.pixelSize: 10
                visible: root.assetRatioWidth !== 1 || root.assetRatioHeight !== 1
            }

            Text {
                text: root.assetDescription
                color: "#CCCCCC"
                font.pixelSize: 10
                font.italic: true
                visible: root.assetDescription !== ""
                wrapMode: Text.Wrap
                width: 200
            }
        }
        
        background: Rectangle {
            color: "#E6000000"
            border.color: "#666666"
            border.width: 1
            radius: 4
        }
    }
}
