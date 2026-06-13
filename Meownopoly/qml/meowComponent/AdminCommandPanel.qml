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
import MapTypes
import utils
import EditorEnum

import UiStyle
import theme

Rectangle {
    id: root

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Theme.spacingL
    color: Theme.background
    border.color: Theme.border
    border.width: 1
    radius: Theme.radiusL
    
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
        anchors.margins: Theme.spacingL
        anchors.bottomMargin: Theme.spacingXS

        color: Theme.surface
        border.color: Theme.border
        border.width: 1
        radius: Theme.radiusM

        ListView {
            id: historyView
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            clip: true
            spacing: Theme.spacingXL
            
            model: historyModel
            
            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
                width: 10
                
                contentItem: Rectangle {
                    implicitWidth: 6
                    radius: Theme.radiusXS
                    color: parent.pressed ? Theme.borderLight : Theme.border
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
                    color: historyMouseArea.containsMouse ? Theme.pressed(Theme.surface) : "transparent"
                    radius: Theme.radiusS

                    Behavior on color {
                        ColorAnimation { duration: Theme.durationFast }
                    }
                }

                Column {
                    id: commandColumn
                    width: parent.width
                    spacing: Theme.spacingXS

                    // Ligne de commande avec timestamp
                    Text {
                        width: parent.width
                        text: "[" + model.timestamp + "] > " + model.command
                        color: Theme.accent
                        font.family: "Consolas, Monaco, Courier New, monospace"
                        font.pixelSize: Theme.fontSizeBody
                        wrapMode: Text.Wrap
                    }

                    // Résultat
                    Text {
                        width: parent.width
                        text: model.result
                        color: model.isError ? Theme.danger : "#a0e0a0"
                        font.family: "Consolas, Monaco, Courier New, monospace"
                        font.pixelSize: Theme.fontSizeBody
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
                color: Theme.textDisabled
                font.family: "Consolas, Monaco, Courier New, monospace"
                font.pixelSize: Theme.fontSizeBody
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
        anchors.margins: Theme.spacingL
        anchors.topMargin: Theme.spacingXS

        height: Math.max(60, Math.min(commandInputFlickable.contentHeight + 20, 150))

        color: Theme.surface
        border.color: commandInput.activeFocus ? Theme.accent : Theme.border
        border.width: commandInput.activeFocus ? 2 : 1
        radius: Theme.radiusM

        Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }
        Behavior on border.width { NumberAnimation { duration: Theme.durationNormal } }
        Behavior on height { NumberAnimation { duration: Theme.durationFast } }

        // Bouton Tests à gauche
        Rectangle {
            id: testsButton
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingM

            width: 70
            color: testsMouseArea.pressed ? Theme.surface :
                   testsMouseArea.containsMouse ? Theme.hover(Theme.surfaceHover) : Theme.surfaceHover
            border.color: Theme.borderLight
            border.width: 1
            radius: Theme.radiusM

            Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

            Text {
                anchors.centerIn: parent
                text: "Tests"
                color: Theme.textSoft
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
            
            MouseArea {
                id: testsMouseArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                
                onClicked: {
                    testWindow.visible = !testWindow.visible
                    if (testWindow.visible) {
                        testWindow.x = 20
                        testWindow.y = 20
                    }
                }
            }
        }
        
        // Bouton Execute à droite
        Rectangle {
            id: executeButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingM

            width: 70
            color: executeMouseArea.pressed ? Theme.surface :
                   executeMouseArea.containsMouse ? Theme.hover(Theme.surfaceHover) : Theme.surfaceHover
            border.color: Theme.borderLight
            border.width: 1
            radius: Theme.radiusM

            Behavior on color { ColorAnimation { duration: Theme.durationNormal } }

            Text {
                anchors.centerIn: parent
                text: "Execute"
                color: Theme.textSoft
                font.pixelSize: Theme.fontSizeSmall
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
            anchors.left: testsButton.right
            anchors.right: executeButton.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: Theme.spacingM
            anchors.rightMargin: Theme.spacingXS

            contentWidth: commandInput.paintedWidth
            contentHeight: commandInput.paintedHeight
            clip: true

            ScrollBar.vertical: ScrollBar {
                policy: commandInputFlickable.contentHeight > height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                width: 8

                contentItem: Rectangle {
                    implicitWidth: 4
                    radius: Theme.radiusXS
                    color: parent.pressed ? Theme.borderLight : Theme.border
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
                
                color: Theme.textSoft
                font.family: "Consolas, Monaco, Courier New, monospace"
                font.pixelSize: Theme.fontSizeBody
                wrapMode: TextEdit.Wrap
                selectByMouse: true
                selectionColor: Theme.accent
                
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
                    color: Theme.textDisabled
                    font: commandInput.font
                }
            }
        }
    }
    
    // Focus automatique sur l'input quand le panel devient visible
    onVisibleChanged: {
        if (visible) {
            commandInput.forceActiveFocus()
        } else {
            // testWindow.visible = false
        }
    }

    TestCommandWindow {
        id: testWindow
        visible: false
        parent: root.parent
        z: UiStyle.z_CHAT_DRAWER + 100
    }
}
