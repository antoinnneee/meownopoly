import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Dialogs
import QtQuick.Layouts 1.15

Item {
    id: root
    width: parent.width
    // height: imageContainer.height + scalingSelector.height
    height: 200

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
            visible: logic.mapInfo.backgroundPath === ""
            
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
                text: qsTr("Choisir une image")
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
            visible: logic.mapInfo.backgroundPath !== ""
            source: logic.mapInfo.backgroundPath
            fillMode: {
                switch(logic.mapInfo.backgroundScaling) {
                    case "stretch": return Image.Stretch;
                    case "fit": return Image.PreserveAspectFit;
                    case "Tile": return Image.Tile;
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
            visible: logic.mapInfo.backgroundPath !== ""
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
                    logic.mapInfo.backgroundPath = "";
                    logic.mapInfo.backgroundScaling = "Fit";
                    // root.imageRemoved();
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
            enabled: logic.mapInfo.backgroundPath === "" || !removeButton.contains(Qt.point(mouseX, mouseY))
        }
    }
    
    // Espace pour information sur l'image sélectionnée
    Rectangle {
        id: imageInfoArea
        width: imageContainer.width
        height: 30
        anchors.top: imageContainer.bottom
        anchors.horizontalCenter: imageContainer.horizontalCenter
        anchors.topMargin: 8
        color: "transparent"
        visible: logic.mapInfo.backgroundPath !== ""
        
        Text {
            anchors.centerIn: parent
            text: {
                var path = logic.mapInfo.backgroundPath;
                var fileName = path.substring(path.lastIndexOf("/") + 1);
                return fileName.replace(/\.[^/.]+$/, ""); // Enlever l'extension
            }
            color: "#AAAAAA"
            font.pixelSize: 12
            elide: Text.ElideMiddle
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
        }
    }
    
    // File dialog for image selection
    FileDialog {
        id: fileDialog
        title: qsTr("Sélectionner une image")
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]
        onAccepted: {
            // Utilisation de selectedFile de la nouvelle API
            logic.mapInfo.backgroundPath = fileDialog.selectedFile;
        }
    }
}
