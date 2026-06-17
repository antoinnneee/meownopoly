import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 100
    color: Theme.surfaceHover
    radius: Theme.radiusXL
    border.color: Theme.borderLight
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
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingL

        Text {
            text: "🚀 Actions"
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            color: Theme.textPrimary
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingL
            
            Button {
                text: "Vérifier"
                enabled: !root.isDownloading
                onClicked: root.checkForUpdatesRequested()
                Layout.preferredWidth: 120
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? Theme.pressed(Theme.accent) : Theme.accent) : Theme.textDisabled
                    radius: Theme.radiusM
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            Button {
                text: "Télécharger"
                enabled: !root.isDownloading && root.latestVersion !== root.currentVersion
                onClicked: root.downloadResourcesRequested()
                Layout.preferredWidth: 120
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? Theme.pressed(Theme.success) : Theme.success) : Theme.textDisabled
                    radius: Theme.radiusM
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            Button {
                text: "Forcer le téléchargement"
                enabled: !root.isDownloading
                onClicked: root.forceDownloadRequested()
                Layout.preferredWidth: 150
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? Theme.warning : "#ff5722") : Theme.textDisabled
                    radius: Theme.radiusM
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeBody
                }
            }

            Item { Layout.fillWidth: true }
            
            Button {
                text: "Lancer le jeu"
                enabled: !root.isDownloading
                onClicked: root.launchGameRequested()
                Layout.preferredWidth: 120
                
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#6a1b9a" : "#9c27b0") : Theme.textDisabled
                    radius: Theme.radiusM
                }

                contentItem: Text {
                    text: parent.text
                    color: Theme.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                }
            }
        }
    }
}
