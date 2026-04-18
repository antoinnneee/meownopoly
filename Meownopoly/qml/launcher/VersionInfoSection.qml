import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 180
    color: "#3a3a3a"
    radius: 10
    border.color: "#555555"
    border.width: 1
    
    property string currentVersion: "0.0.0"
    property string latestVersion: "0.0.0"
    property string downloadStatus: "Prêt"
    property bool isDownloading: false
    property real downloadProgress: 0.0
    property real bytesReceived: 0
    property real bytesTotal: 0
    property string versionDescription: ""
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        Text {
            text: "📦 Gestion des versions"
            font.pixelSize: 16
            font.bold: true
            color: "#ffffff"
        }
        
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 20
            rowSpacing: 8
            
            Text { 
                text: "Version actuelle:"
                color: "#cccccc"
            }
            Text { 
                text: root.currentVersion
                color: "#4CAF50"
                font.bold: true
            }
            
            Text { 
                text: "Dernière version:"
                color: "#cccccc"
            }
            Text { 
                text: root.latestVersion
                color: root.latestVersion !== root.currentVersion ? "#FF9800" : "#4CAF50"
                font.bold: true
            }
            
            Text {
                text: "Statut:"
                color: "#cccccc"
            }
            Text {
                text: root.downloadStatus
                color: root.isDownloading ? "#2196F3" : "#4CAF50"
                font.bold: true
            }

            Text {
                text: "Description:"
                color: "#cccccc"
                visible: root.versionDescription.length > 0
            }
            Text {
                text: root.versionDescription
                color: "#aaaaaa"
                font.italic: true
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: root.versionDescription.length > 0
            }
        }
        
        // Barre de progression
        ProgressBar {
            Layout.fillWidth: true
            visible: root.isDownloading
            value: root.downloadProgress
            height: 25
            
            background: Rectangle {
                color: "#2a2a2a"
                radius: 4
                border.color: "#555555"
                border.width: 1
            }
            
            contentItem: Item {
                Rectangle {
                    width: parent.parent.value * parent.width
                    height: parent.height
                    radius: 4
                    color: "#4CAF50"
                }
                
                Text {
                    anchors.centerIn: parent
                    text: {
                        let percent = Math.round(root.downloadProgress * 100) + "%"
                        if (root.bytesTotal > 0) {
                            let received = (root.bytesReceived / (1024*1024)).toFixed(1)
                            let total = (root.bytesTotal / (1024*1024)).toFixed(1)
                            return percent + " (" + received + " / " + total + " Mo)"
                        }
                        return percent
                    }
                    color: "#ffffff"
                    font.bold: true
                }
            }
        }
    }
}
