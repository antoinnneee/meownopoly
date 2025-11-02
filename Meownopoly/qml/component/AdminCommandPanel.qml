/*
 * AdminCommandPanel.qml - Panel de commande admin style chat
 * 
 * Design simplifié avec anchors pour éviter les problèmes de Layout
 * Architecture: ListView pour historique + zone input fixe en bas
 * 
 * Keyboard shortcuts:
 * - Enter: Execute command
 * - Shift+Enter: Insert newline
 */

import QtQuick 2.15
import QtQuick.Controls 2.15
import AssetManager


Rectangle {
    id: root
    
    color: "#1e1e1e"
    border.color: "#3a3a3a"
    border.width: 1
    radius: 8
    
    // Modèle pour stocker l'historique des commandes
    ListModel {
        id: historyModel
    }
    
    // Fonction pour formater un résultat
    function formatResult(result) {
        if (result === undefined) return "undefined"
        if (result === null) return "null"
        if (typeof result === "object") {
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
        var timestamp = new Date().toLocaleTimeString()
        
        try {
            result = eval(commandText)
            var formattedResult = formatResult(result)
            
            historyModel.append({
                "timestamp": timestamp,
                "command": commandText,
                "result": formattedResult,
                "isError": false
            })
        } catch (e) {
            historyModel.append({
                "timestamp": timestamp,
                "command": commandText,
                "result": e.toString(),
                "isError": true
            })
        }
        
        // Scroll vers le bas
        historyView.positionViewAtEnd()
    }
    
    // Fonction pour effacer l'historique
    function clearChat() {
        historyModel.clear()
    }
    
    // Zone d'historique des commandes
    Rectangle {
        id: historyContainer
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: inputContainer.top
        anchors.margins: 10
        anchors.bottomMargin: 5
        
        color: "#2d2d2d"
        border.color: "#3a3a3a"
        border.width: 1
        radius: 6
        
        ListView {
            id: historyView
            anchors.fill: parent
            anchors.margins: 8
            clip: true
            spacing: 12
            
            model: historyModel
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 10
                
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: 3
                    color: parent.pressed ? "#555555" : "#444444"
                }
                
                background: Rectangle {
                    color: "transparent"
                }
            }
            
            delegate: Item {
                width: historyView.width
                height: commandColumn.height
                
                Rectangle {
                    anchors.fill: parent
                    color: historyMouseArea.containsMouse ? "#252525" : "transparent"
                    radius: 4
                    
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
                
                Column {
                    id: commandColumn
                    width: parent.width
                    spacing: 4
                    
                    // Ligne de commande avec timestamp
                    Text {
                        width: parent.width
                        text: "[" + model.timestamp + "] > " + model.command
                        color: "#4a90e2"
                        font.family: "Consolas, Monaco, Courier New, monospace"
                        font.pointSize: 9
                        wrapMode: Text.Wrap
                    }
                    
                    // Résultat
                    Text {
                        width: parent.width
                        text: model.result
                        color: model.isError ? "#e74c3c" : "#a0e0a0"
                        font.family: "Consolas, Monaco, Courier New, monospace"
                        font.pointSize: 9
                        wrapMode: Text.Wrap
                    }
                }
                
                MouseArea {
                    id: historyMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    
                    onClicked: {
                        commandInput.text = model.command
                        commandInput.forceActiveFocus()
                        commandInput.cursorPosition = commandInput.text.length
                    }
                }
            }
            
            // Message par défaut si aucune commande
            Text {
                anchors.centerIn: parent
                visible: historyModel.count === 0
                text: "Admin Console Ready\nPress ² to show/hide"
                color: "#555555"
                font.family: "Consolas, Monaco, Courier New, monospace"
                font.pointSize: 10
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
    
    // Zone de saisie en bas
    Rectangle {
        id: inputContainer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 10
        anchors.topMargin: 5
        
        height: Math.max(60, Math.min(commandInputFlickable.contentHeight + 20, 150))
        
        color: "#2d2d2d"
        border.color: commandInput.activeFocus ? "#4a90e2" : "#3a3a3a"
        border.width: commandInput.activeFocus ? 2 : 1
        radius: 6
        
        Behavior on border.color { ColorAnimation { duration: 150 } }
        Behavior on border.width { NumberAnimation { duration: 150 } }
        Behavior on height { NumberAnimation { duration: 100 } }
        
        // Bouton Execute à droite
        Rectangle {
            id: executeButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 8
            
            width: 70
            color: executeMouseArea.pressed ? "#2a2a2a" : 
                   executeMouseArea.containsMouse ? "#4a4a4a" : "#3a3a3a"
            border.color: "#555555"
            border.width: 1
            radius: 6
            
            Behavior on color { ColorAnimation { duration: 150 } }
            
            Text {
                anchors.centerIn: parent
                text: "Execute"
                color: "#e0e0e0"
                font.pixelSize: 11
                font.bold: true
            }
            
            MouseArea {
                id: executeMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    root.executeCommand(commandInput.text)
                    commandInput.forceActiveFocus()
                }
            }
        }
        
        // Zone de saisie scrollable
        Flickable {
            id: commandInputFlickable
            anchors.left: parent.left
            anchors.right: executeButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 8
            anchors.rightMargin: 4
            
            contentWidth: commandInput.paintedWidth
            contentHeight: commandInput.paintedHeight
            clip: true
            
            ScrollBar.vertical: ScrollBar {
                policy: commandInputFlickable.contentHeight > height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                width: 8
                
                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: 2
                    color: parent.pressed ? "#555555" : "#444444"
                }
            }
            
            function ensureVisible(r) {
                if (contentY >= r.y)
                    contentY = r.y
                else if (contentY + height <= r.y + r.height)
                    contentY = r.y + r.height - height
            }
            
            TextEdit {
                id: commandInput
                width: commandInputFlickable.width - 10
                
                color: "#e0e0e0"
                font.family: "Consolas, Monaco, Courier New, monospace"
                font.pointSize: 10
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                selectionColor: "#4a90e2"
                
                text: ""
                
                onCursorRectangleChanged: commandInputFlickable.ensureVisible(cursorRectangle)
                
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (event.modifiers & Qt.ShiftModifier) {
                            // Shift+Enter: insérer une nouvelle ligne (comportement par défaut)
                            event.accepted = false
                        } else {
                            // Enter: exécuter la commande
                            root.executeCommand(commandInput.text)
                            event.accepted = true
                            commandInput.focus = false
                        }
                    } else if (event.key === Qt.Key_Escape) {
                        // Escape: fermer le panel
                        root.visible = false
                        event.accepted = true
                        commandInput.focus = false
                        root.parent.forceActiveFocus()
                    }
                }
                
                // Placeholder text
                Text {
                    anchors.fill: parent
                    visible: commandInput.text.length === 0 && !commandInput.activeFocus
                    text: "Enter command... (Enter = execute, Shift+Enter = newline)"
                    color: "#555555"
                    font: commandInput.font
                }
            }
        }
    }
    
    // Focus automatique sur l'input quand le panel devient visible
    onVisibleChanged: {
        if (visible) {
            commandInput.forceActiveFocus()
        }
    }
}
