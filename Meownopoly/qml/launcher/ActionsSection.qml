import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 100
    color: "#3a3a3a"
    radius: 10
    border.color: "#555555"
    border.width: 1
    
    property bool isDownloading: false
    property string currentVersion: "0.0.0"
    property string latestVersion: "0.0.0"
    
    signal checkForUpdatesRequested()
    signal downloadResourcesRequested()
    signal forceDownloadRequested()
    signal launchGameRequested()
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10
        
        Text {
            text: "🚀 Actions"
            font.pixelSize: 16
            font.bold: true
            color: "#ffffff"
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Button {
                text: "Vérifier"
                enabled: !root.isDownloading
                onClicked: root.checkForUpdatesRequested()
                Layout.preferredWidth: 120
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#1976d2" : "#2196f3") : "#666666"
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                }
            }
            
            Button {
                text: "Télécharger"
                enabled: !root.isDownloading && root.latestVersion !== root.currentVersion
                onClicked: root.downloadResourcesRequested()
                Layout.preferredWidth: 120
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#388e3c" : "#4caf50") : "#666666"
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                }
            }
            
            Button {
                text: "Forcer"
                enabled: !root.isDownloading
                onClicked: root.forceDownloadRequested()
                Layout.preferredWidth: 100
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#f57c00" : "#ff9800") : "#666666"
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                }
            }
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "Lancer le jeu"
                enabled: !root.isDownloading
                onClicked: root.launchGameRequested()
                Layout.preferredWidth: 120
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#6a1b9a" : "#9c27b0") : "#666666"
                    radius: 6
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }
}
