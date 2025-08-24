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
        }
        
        // Barre de progression
        ProgressBar {
            Layout.fillWidth: true
            visible: root.isDownloading
            value: root.downloadProgress
            
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
                    text: Math.round(root.downloadProgress * 100) + "%"
                    color: "#ffffff"
                    font.bold: true
                }
            }
        }
    }
}
