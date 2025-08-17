import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import Qt.labs.platform

Rectangle {
    id: root
    color: "#1a1a1a"
    
    signal backRequested()
    
    // Title
    Text {
        id: title
        text: "Asset Archiver"
        color: "#ffffff"
        font.pixelSize: 32
        font.bold: true
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 40
        }
    }
    
    // Main content area
    Rectangle {
        id: contentArea
        color: "#2a2a2a"
        radius: 10
        anchors {
            top: title.bottom
            topMargin: 40
            left: parent.left
            right: parent.right
            bottom: backButton.top
            margins: 40
            bottomMargin: 20
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 30
            spacing: 30
            
            // Compression Section
            GroupBox {
                id: compressionGroup
                title: "Compression des Assets"
                Layout.fillWidth: true
                
                background: Rectangle {
                    color: "#3a3a3a"
                    radius: 8
                    border.color: "#4a4a4a"
                    border.width: 1
                }
                
                label: Text {
                    text: compressionGroup.title
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    // Source folder selection
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: "Dossier source:"
                            color: "#ffffff"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        TextField {
                            id: sourceFolderField
                            placeholderText: "Sélectionnez le dossier à compresser..."
                            Layout.fillWidth: true
                            color: "#ffffff"
                            
                            background: Rectangle {
                                color: "#4a4a4a"
                                radius: 4
                                border.color: sourceFolderField.focus ? "#2196f3" : "#5a5a5a"
                                border.width: 1
                            }
                        }
                        
                        Button {
                            id: sourceBrowseButton
                            text: "Parcourir..."
                            onClicked: sourceFolderDialog.open()
                            
                            background: Rectangle {
                                color: sourceBrowseButton.pressed ? "#1976d2" : "#2196f3"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: sourceBrowseButton.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    
                    // Destination file selection
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: "Fichier destination:"
                            color: "#ffffff"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        TextField {
                            id: destinationFileField
                            placeholderText: "assets_compressed.meow"
                            text: "assets_compressed.meow"
                            Layout.fillWidth: true
                            color: "#ffffff"
                            
                            background: Rectangle {
                                color: "#4a4a4a"
                                radius: 4
                                border.color: destinationFileField.focus ? "#2196f3" : "#5a5a5a"
                                border.width: 1
                            }
                        }
                        
                        Button {
                            id: destFileBrowseButton
                            text: "Parcourir..."
                            onClicked: destinationFileDialog.open()
                            
                            background: Rectangle {
                                color: destFileBrowseButton.pressed ? "#1976d2" : "#2196f3"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: destFileBrowseButton.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    
                    // Compress button
                    Button {
                        id: compressButton
                        text: "Compresser le dossier"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        enabled: sourceFolderField.text.length > 0 && destinationFileField.text.length > 0
                        
                        background: Rectangle {
                            color: compressButton.enabled ? 
                                   (compressButton.pressed ? "#2e7d32" : "#4caf50") : 
                                   "#666666"
                            radius: 8
                        }
                        
                        contentItem: Text {
                            text: compressButton.text
                            color: "white"
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            if (typeof folderCompressor !== "undefined" && folderCompressor) {
                                var success = folderCompressor.compressFolder(sourceFolderField.text, destinationFileField.text)
                                if (success) {
                                    statusText.text = "✓ Compression réussie!"
                                    statusText.color = "#4caf50"
                                } else {
                                    statusText.text = "✗ Erreur lors de la compression"
                                    statusText.color = "#f44336"
                                }
                            }
                        }
                    }
                }
            }
            
            // Decompression Section
            GroupBox {
                id: decompressionGroup
                title: "Décompression des Assets"
                Layout.fillWidth: true
                
                background: Rectangle {
                    color: "#3a3a3a"
                    radius: 8
                    border.color: "#4a4a4a"
                    border.width: 1
                }
                
                label: Text {
                    text: decompressionGroup.title
                    color: "#ffffff"
                    font.pixelSize: 18
                    font.bold: true
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 15
                    
                    // Source file selection
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: "Fichier source:"
                            color: "#ffffff"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        TextField {
                            id: sourceFileField
                            placeholderText: "Sélectionnez le fichier compressé..."
                            Layout.fillWidth: true
                            color: "#ffffff"
                            
                            background: Rectangle {
                                color: "#4a4a4a"
                                radius: 4
                                border.color: sourceFileField.focus ? "#2196f3" : "#5a5a5a"
                                border.width: 1
                            }
                        }
                        
                        Button {
                            id: sourceFileBrowseButton
                            text: "Parcourir..."
                            onClicked: sourceFileDialog.open()
                            
                            background: Rectangle {
                                color: sourceFileBrowseButton.pressed ? "#1976d2" : "#2196f3"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: sourceFileBrowseButton.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    
                    // Destination folder selection
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: "Dossier destination:"
                            color: "#ffffff"
                            font.pixelSize: 14
                            Layout.preferredWidth: 120
                        }
                        
                        TextField {
                            id: destinationFolderField
                            placeholderText: "Sélectionnez le dossier de destination..."
                            Layout.fillWidth: true
                            color: "#ffffff"
                            
                            background: Rectangle {
                                color: "#4a4a4a"
                                radius: 4
                                border.color: destinationFolderField.focus ? "#2196f3" : "#5a5a5a"
                                border.width: 1
                            }
                        }
                        
                        Button {
                            id: destFolderBrowseButton
                            text: "Parcourir..."
                            onClicked: destinationFolderDialog.open()
                            
                            background: Rectangle {
                                color: destFolderBrowseButton.pressed ? "#1976d2" : "#2196f3"
                                radius: 4
                            }
                            
                            contentItem: Text {
                                text: destFolderBrowseButton.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                    
                    // Decompress button
                    Button {
                        id: decompressButton
                        text: "Décompresser le fichier"
                        Layout.fillWidth: true
                        Layout.preferredHeight: 50
                        enabled: sourceFileField.text.length > 0 && destinationFolderField.text.length > 0
                        
                        background: Rectangle {
                            color: decompressButton.enabled ? 
                                   (decompressButton.pressed ? "#6a1b9a" : "#9c27b0") : 
                                   "#666666"
                            radius: 8
                        }
                        
                        contentItem: Text {
                            text: decompressButton.text
                            color: "white"
                            font.pixelSize: 16
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                        onClicked: {
                            if (typeof folderCompressor !== "undefined" && folderCompressor) {
                                var success = folderCompressor.decompressFolder(sourceFileField.text, destinationFolderField.text)
                                if (success) {
                                    statusText.text = "✓ Décompression réussie!"
                                    statusText.color = "#4caf50"
                                } else {
                                    statusText.text = "✗ Erreur lors de la décompression"
                                    statusText.color = "#f44336"
                                }
                            }
                        }
                    }
                }
            }
            
            // Status text
            Text {
                id: statusText
                text: "Prêt à archiver vos assets"
                color: "#cccccc"
                font.pixelSize: 14
                Layout.alignment: Qt.AlignHCenter
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    
    // Back button
    Button {
        id: backButton
        text: "← Retour"
        anchors {
            left: parent.left
            bottom: parent.bottom
            margins: 20
        }
        
        background: Rectangle {
            color: backButton.pressed ? "#424242" : "#616161"
            radius: 8
        }
        
        contentItem: Text {
            text: backButton.text
            color: "white"
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        
        onClicked: {
            root.backRequested()
        }
    }
    
    // File and folder dialogs
    FolderDialog {
        id: sourceFolderDialog
        title: "Sélectionner le dossier à compresser"
        onAccepted: {
            sourceFolderField.text = folder.toString().replace("file:///", "").replace("file://", "")
        }
    }
    
    FileDialog {
        id: destinationFileDialog
        title: "Sauvegarder le fichier compressé sous..."
        fileMode: FileDialog.SaveFile
        nameFilters: ["Fichiers de données (*.meow)", "Tous les fichiers (*)"]
        onAccepted: {
            destinationFileField.text = file.toString().replace("file:///", "").replace("file://", "")
        }
    }
    
    FileDialog {
        id: sourceFileDialog
        title: "Sélectionner le fichier compressé"
        fileMode: FileDialog.OpenFile
        nameFilters: ["Fichiers de données (*.meow)", "Tous les fichiers (*)"]
        onAccepted: {
            sourceFileField.text = file.toString().replace("file:///", "").replace("file://", "")
        }
    }
    
    FolderDialog {
        id: destinationFolderDialog
        title: "Sélectionner le dossier de destination"
        onAccepted: {
            destinationFolderField.text = folder.toString().replace("file:///", "").replace("file://", "")
        }
    }
}
