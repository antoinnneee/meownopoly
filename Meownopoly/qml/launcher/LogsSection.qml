/*
 * LogsSection.qml - Journal des opérations du launcher
 *
 * Cette section affiche l'historique des opérations et permet de :
 * - Suivre les actions en cours
 * - Voir les erreurs et succès
 * - Réinitialiser l'état du launcher
 *
 * Fonctionnalités :
 * ----------------
 * - Affichage chronologique des messages
 * - Horodatage automatique
 * - Emojis pour une meilleure lisibilité
 * - Bouton d'effacement des logs
 * - Bouton de réinitialisation d'état
 * - Sélection et copie du texte
 *
 * Format des messages :
 * ------------------
 * [HH:MM:SS] Message
 * Exemples :
 * - ✅ Succès
 * - ❌ Erreur
 * - 📦 Actions sur les paquets
 * - 🔄 Réinitialisation
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme
import ui_item

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.minimumHeight: 200
    Layout.preferredHeight: 250
    color: Theme.surfaceHover
    radius: Theme.radiusXL
    border.color: Theme.borderLight
    border.width: 1
    
    property alias logText: logArea.text
    
    signal resetDownloadStateRequested()
    
    function addLog(message) {
        var timestamp = new Date().toLocaleTimeString()
        logArea.text += "[" + timestamp + "] " + message + "\n"
        logArea.cursorPosition = logArea.length
    }
    
    function clearLogs() {
        logArea.text = ""
    }
    
    function resetDownloadState() {
        resetDownloadStateRequested()
        addLog("🔄 État de téléchargement réinitialisé")
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingL

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "📋 Logs d'activité"
                font.pixelSize: Theme.fontSizeLarge
                font.bold: true
                color: Theme.textPrimary
            }

            Item { Layout.fillWidth: true }

            Row {
                spacing: Theme.spacingXS

                MeowButton {
                    text: "Effacer"
                    variant: "danger"
                    fontSize: Theme.fontSizeCaption
                    onClicked: root.clearLogs()
                }

                MeowButton {
                    text: "Reset État"
                    variant: "warning"
                    fontSize: Theme.fontSizeCaption
                    onClicked: root.resetDownloadState()
                }
            }
        }
        
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            TextArea {
                id: logArea
                readOnly: true
                wrapMode: TextArea.Wrap
                selectByMouse: true
                color: Theme.textPrimary
                font.family: "Consolas, Monaco, monospace"
                font.pixelSize: Theme.fontSizeSmall
                topPadding: Theme.spacingL

                background: Rectangle {
                    color: Theme.background
                    border.color: Theme.borderLight
                    border.width: 1
                    radius: Theme.radiusM
                    clip: true
                }
            }
        }
    }
}
