import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme
import ui_item

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
            
            MeowButton {
                text: "Vérifier"
                enabled: !root.isDownloading
                onClicked: root.checkForUpdatesRequested()
                Layout.preferredWidth: 120
                variant: "primary"
                fontSize: Theme.fontSizeBody
            }

            MeowButton {
                text: "Télécharger"
                enabled: !root.isDownloading && root.latestVersion !== root.currentVersion
                onClicked: root.downloadResourcesRequested()
                Layout.preferredWidth: 120
                variant: "success"
                fontSize: Theme.fontSizeBody
            }

            MeowButton {
                text: "Forcer le téléchargement"
                enabled: !root.isDownloading
                onClicked: root.forceDownloadRequested()
                Layout.preferredWidth: 150
                baseColor: "#ff5722"
                fontSize: Theme.fontSizeBody
            }

            Item { Layout.fillWidth: true }

            MeowButton {
                text: "Lancer le jeu"
                enabled: !root.isDownloading
                onClicked: root.launchGameRequested()
                Layout.preferredWidth: 120
                baseColor: "#9c27b0"
                fontSize: Theme.fontSizeBody
            }
        }
    }
}
