pragma ComponentBehavior:Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../menu/"

Rectangle {
    id: root
    width: 800
    height: 600
    color: "#f0f0f0"
    
    Column {
        anchors.centerIn: parent
        spacing: 20
        
        Text {
            text: "Test du PawMenu"
            font.pixelSize: 24
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Text {
            text: "Cliquez sur la patte pour ouvrir le menu"
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        // Instance du PawMenu
        PawMenu {
            id: pawMenu
            anchors.horizontalCenter: parent.horizontalCenter
            
            actions: [
                {
                    icon: AssetManager.getDecorationPath("grass", 0),
                    label: "Déplacer",
                    action: function() {
                        logText.text += "Action: Déplacer\n"
                    },
                    enabled: true
                },
                {
                    icon: AssetManager.getDecorationPath("grass", 1),
                    label: "Attaquer",
                    action: function() {
                        logText.text += "Action: Attaquer\n"
                    },
                    enabled: true
                },
                {
                    icon: AssetManager.getDecorationPath("grass", 2),
                    label: "Défendre",
                    action: function() {
                        logText.text += "Action: Défendre\n"
                    },
                    enabled: true
                },
                {
                    icon: AssetManager.getDecorationPath("grass", 3),
                    label: "Dormir",
                    action: function() {
                        logText.text += "Action: Dormir\n"
                    },
                    enabled: false
                }
            ]
            
            onActionTriggered: function(actionIndex, action) {
                logText.text += `Action ${actionIndex} déclenchée: ${action.label}\n`
            }
            
            onMenuToggled: function(opened) {
                logText.text += `Menu ${opened ? 'ouvert' : 'fermé'}\n`
            }
        }
        
        // Zone de log
        ScrollView {
            width: 400
            height: 200
            anchors.horizontalCenter: parent.horizontalCenter
            
            TextArea {
                id: logText
                text: "Log des actions:\n"
                readOnly: true
                wrapMode: TextArea.Wrap
            }
        }
        
        Button {
            text: "Effacer le log"
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: logText.text = "Log des actions:\n"
        }
    }
}
