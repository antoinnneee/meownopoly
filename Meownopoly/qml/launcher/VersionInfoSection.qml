import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 180
    color: Theme.surfaceHover
    radius: Theme.radiusXL
    border.color: Theme.borderLight
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
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingL

        Text {
            text: "📦 Gestion des versions"
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: Theme.textPrimary
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spacingHuge
            rowSpacing: Theme.spacingM

            Text {
                text: "Version actuelle:"
                color: Theme.textSecondary
            }
            Text {
                text: root.currentVersion
                color: Theme.success
                font.bold: true
            }

            Text {
                text: "Dernière version:"
                color: Theme.textSecondary
            }
            Text {
                text: root.latestVersion
                color: root.latestVersion !== root.currentVersion ? Theme.warning : Theme.success
                font.bold: true
            }

            Text {
                text: "Statut:"
                color: Theme.textSecondary
            }
            Text {
                text: root.downloadStatus
                color: root.isDownloading ? Theme.accent : Theme.success
                font.bold: true
            }

            Text {
                text: "Description:"
                color: Theme.textSecondary
                visible: root.versionDescription.length > 0
            }
            Text {
                text: root.versionDescription
                color: Theme.textHint
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
                color: Theme.surface
                radius: Theme.radiusS
                border.color: Theme.borderLight
                border.width: 1
            }

            contentItem: Item {
                Rectangle {
                    width: parent.parent.value * parent.width
                    height: parent.height
                    radius: Theme.radiusS
                    color: Theme.success
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
                    color: Theme.textPrimary
                    font.bold: true
                }
            }
        }
    }
}
