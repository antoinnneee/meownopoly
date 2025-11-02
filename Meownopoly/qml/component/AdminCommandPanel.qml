/*
 * AdminCommandPanel.qml - Panel de commande admin style chat
 *
 * Ce composant affiche une interface de type chat pour exécuter des commandes admin.
 * - Zone de chat scrollable affichant l'historique des commandes et leurs résultats
 * - Barre de commande multiligne pour saisir des commandes JavaScript
 * - Exécution des commandes avec eval() et affichage des résultats
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    
    // Propriétés
    property alias commandHistory: chatArea.text
    
    // Style sobre avec UI foncée
    color: "#1e1e1e"
    border.color: "#3a3a3a"
    border.width: 1
    radius: 8
    
    // Fonction pour ajouter une commande et son résultat au chat
    function addCommand(command, result) {
        var timestamp = new Date().toLocaleTimeString()
        var commandLine = "[" + timestamp + "] > " + command
        
        // Ajouter la commande et le résultat
        if (chatArea.text.length > 0) {
            chatArea.text += "\n"
        }
        chatArea.text += commandLine + "\n" + result
        
        // Auto-scroll vers le bas
        chatArea.cursorPosition = chatArea.length
        
        // Utiliser un Timer pour s'assurer que le scroll fonctionne après que le texte soit ajouté
        scrollTimer.restart()
    }
    
    Timer {
        id: scrollTimer
        interval: 10
        onTriggered: {
            // Accéder au Flickable interne du ScrollView pour faire défiler
            var flickable = chatScrollView.contentItem
            if (flickable) {
                flickable.contentY = flickable.contentHeight - flickable.height
            }
        }
    }
    
    // Fonction pour effacer le chat
    function clearChat() {
        chatArea.text = ""
    }
    
    // Fonction pour formater un résultat pour l'affichage
    function formatResult(result) {
        if (result === undefined) {
            return "undefined"
        }
        if (result === null) {
            return "null"
        }
        if (typeof result === "object") {
            // Pour les objets, essayer de les convertir en JSON pour un meilleur affichage
            try {
                return JSON.stringify(result, null, 2)
            } catch (e) {
                return String(result)
            }
        }
        return String(result)
    }
    
    // Fonction pour exécuter une commande
    function executeCommand(commandText) {
        if (!commandText || commandText.trim() === "") {
            return
        }
        
        var result
        var error = null
        
        try {
            // Exécuter la commande avec eval()
            result = eval(commandText)
            
            // Formater et afficher le résultat
            var formattedResult = formatResult(result)
            addCommand(commandText, formattedResult)
        } catch (e) {
            // En cas d'erreur, afficher le message d'erreur
            error = e.toString()
            addCommand(commandText, "Error: " + error)
        }

    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        
        // Zone de chat scrollable
        ScrollView {
            id: chatScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            
            ScrollBar.vertical.policy: ScrollBar.AsNeeded
            
            TextArea {
                id: chatArea
                readOnly: true
                wrapMode: TextArea.Wrap
                selectByMouse: true
                color: "#e0e0e0"
                font.family: "Consolas, Monaco, 'Courier New', monospace"
                font.pointSize: 9
                topPadding: 8
                leftPadding: 8
                rightPadding: 8
                bottomPadding: 8
                
                background: Rectangle {
                    color: "#2d2d2d"
                    border.color: "#3a3a3a"
                    border.width: 1
                    radius: 6
                    clip: true
                    width: chatArea.width
                    height: chatArea.height
                }
            }
        }
        
        // Barre de commande admin
        RowLayout {
            Layout.maximumHeight: 150
            Layout.fillWidth: true
            Layout.preferredHeight: 71
            spacing: 8
            
            TextArea {
                id: commandInput
                Layout.fillWidth: true
                Layout.fillHeight: false
                wrapMode: TextArea.Wrap
                Layout.maximumHeight: 150
                placeholderText: "Enter admin command..."
                color: "#e0e0e0"
                font.family: "Consolas, Monaco, 'Courier New', monospace"
                font.pointSize: 10
                selectByMouse: true
                
                // Support pour Ctrl+Enter ou Enter pour exécuter
                Keys.onPressed: function(event) {
                    if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && 
                        (event.modifiers & Qt.ControlModifier)) {
                        root.executeCommand(commandInput.text)
                        event.accepted = true
                    }
                }
                background: Rectangle {
                    implicitWidth: commandInput.width
                    implicitHeight: commandInput.height
                    color: "#2d2d2d"
                    border.color: "#3a3a3a"
                    border.width: 1
                }

            }
            
            Button {
                id: executeButton
                Layout.preferredWidth: 80
                Layout.fillHeight: false
                text: "Execute"
                
                onClicked: {
                    root.executeCommand(commandInput.text)
                }
                
                background: Rectangle {
                    color: executeButton.pressed ? "#2a2a2a" : 
                           executeButton.hovered ? "#4a4a4a" : "#3a3a3a"
                    border.color: "#555555"
                    border.width: 1
                    radius: 6
                    
                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }
                }
                
                contentItem: Text {
                    text: executeButton.text
                    color: "#e0e0e0"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    font.pixelSize: 12
                    font.bold: true
                }
            }
        }
    }
}

