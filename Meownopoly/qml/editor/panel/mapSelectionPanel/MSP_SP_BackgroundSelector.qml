import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15

Item {
    id: root
    width: parent.width
    height: imageContainer.height + scalingSelector.height
    
    property string imagePath
    property string scalingMode: "stretch" // stretch, fit, repeat
    
    signal imageSelected(string path)
    signal scalingModeSelected(string mode)
    signal imageRemoved()
    
    // Image selection square
    Rectangle {
        id: imageContainer
        width: Math.min(root.width, 200)
        height: width
        anchors.horizontalCenter: parent.horizontalCenter
        color: "#222222"
        border.color: mouseArea.containsMouse ? "#E91E63" : "#444444"
        border.width: mouseArea.containsMouse ? 2 : 1
        radius: 8
        
        // Default image icon (shown when no image is selected)
        Column {
            anchors.centerIn: parent
            spacing: 10
            visible: backgroundPath === ""
            
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 48
                height: 48
                color: "transparent"
                
                Text {
                    anchors.fill: parent
                    text: "📷"
                    font.pixelSize: 32
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: "#AAAAAA"
                }
            }
            
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Choisir une image"
                color: "#AAAAAA"
                font.pixelSize: 14
                opacity: 0.7
            }
        }
        
        // Selected image
        Image {
            id: selectedImage
            anchors.fill: parent
            anchors.margins: 4
            visible: backgroundPath !== ""
            source: backgroundPath
            fillMode: {
                switch(root.scalingMode) {
                    case "stretch": return Image.Stretch;
                    case "fit": return Image.PreserveAspectFit;
                    case "repeat": return Image.Tile;
                    default: return Image.Stretch;
                }
            }
        }
        
        // Remove image button
        Rectangle {
            id: removeButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 4
            width: 24
            height: 24
            radius: 12
            color: "#CC2222"
            visible: backgroundPath !== ""
            opacity: removeMouseArea.containsMouse ? 1.0 : 0.8
            z: 10  // Assure que le bouton est au-dessus de l'image
            
            Text {
                anchors.centerIn: parent
                text: "×"
                font.pixelSize: 16
                font.bold: true
                color: "white"
            }
            
            MouseArea {
                id: removeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    backgroundPath = "";
                    backgroundScaling = "fit";
                    root.imageRemoved();
                }
            }
        }
        
        // Mouse area for image selection
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: fileDialog.open()
            // Évite de déclencher le click sur le bouton de suppression
            propagateComposedEvents: false
            // Désactive les clics dans la zone du bouton de suppression
            enabled: backgroundPath === "" || !removeButton.contains(Qt.point(mouseX, mouseY))
        }
    }
    
    // Scaling mode selector (appears when image is selected)
    Rectangle {
        id: scalingSelector
        width: imageContainer.width
        height: 30
        anchors.top: imageContainer.bottom
        anchors.horizontalCenter: imageContainer.horizontalCenter
        anchors.topMargin: 8
        color: "transparent"
        visible: backgroundPath !== ""
        
        Row {
            anchors.fill: parent
            spacing: 0
            
            // Stretch button
            Rectangle {
                width: parent.width / 3
                height: parent.height
                color: root.scalingMode === "stretch" ? "#E91E63" : "transparent"
                border.color: "#444444"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: "Stretch"
                    color: root.scalingMode === "stretch" ? "white" : "#AAAAAA"
                    font.pixelSize: 12
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.scalingMode = "stretch";
                        scalingModeSelected(root.scalingMode);
                    }
                }
            }
            
            // Fit button
            Rectangle {
                width: parent.width / 3
                height: parent.height
                color: root.scalingMode === "fit" ? "#E91E63" : "transparent"
                border.color: "#444444"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: "Fit"
                    color: root.scalingMode === "fit" ? "white" : "#AAAAAA"
                    font.pixelSize: 12
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.scalingMode = "fit";
                        root.scalingModeSelected(root.scalingMode);
                    }
                }
            }
            
            // Repeat button
            Rectangle {
                width: parent.width / 3
                height: parent.height
                color: root.scalingMode === "repeat" ? "#E91E63" : "transparent"
                border.color: "#444444"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: "Repeat"
                    color: root.scalingMode === "repeat" ? "white" : "#AAAAAA"
                    font.pixelSize: 12
                }
                
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        root.scalingMode = "repeat";
                        root.scalingModeSelected(root.scalingMode);
                    }
                }
            }
        }
    }
    
    // File dialog for image selection
    FileDialog {
        id: fileDialog
        title: "Sélectionner une image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]
        onAccepted: {
            // Utilisation de selectedFile de la nouvelle API
            backgroundPath = fileDialog.selectedFile;
            // root.imageSelected(backgroundPath);
            // root.scalingModeSelected(backgroundScaling)
            logic.backgroundInfo.backgroundPath = backgroundPath;
            logic.backgroundInfo.backgroundScaling = backgroundScaling;

        }
    }
}
