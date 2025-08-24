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

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.minimumHeight: 200
    Layout.preferredHeight: 250
    color: "#3a3a3a"
    radius: 10
    border.color: "#555555"
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
        anchors.margins: 15
        spacing: 10
        
        RowLayout {
            Layout.fillWidth: true
            
            Text {
                text: "📋 Logs d'activité"
                font.pixelSize: 16
                font.bold: true
                color: "#ffffff"
            }
            
            Item { Layout.fillWidth: true }
            
            Row {
                spacing: 5
                
                Button {
                    text: "Effacer"
                    onClicked: root.clearLogs()
                    
                    background: Rectangle {
                        color: parent.pressed ? "#d32f2f" : "#f44336"
                        radius: 4
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 10
                    }
                }
                
                Button {
                    text: "Reset État"
                    onClicked: root.resetDownloadState()
                    
                    background: Rectangle {
                        color: parent.pressed ? "#f57c00" : "#ff9800"
                        radius: 4
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 10
                    }
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
                color: "#ffffff"
                font.family: "Consolas, Monaco, monospace"
                font.pixelSize: 11
                topPadding: 10
                
                background: Rectangle {
                    color: "#1e1e1e"
                    border.color: "#555555"
                    border.width: 1
                    radius: 6
                    clip: true
                }
            }
        }
    }
}
