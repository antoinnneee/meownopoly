pragma ComponentBehavior:Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../menu/"
import "../menu/pawTools.js" as PawTools
import theme

Rectangle {
    id: root
    width: 800
    height: 700
    color: "#f0f0f0"
    
    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingHuge
        
        Text {
            text: "Test du PawMenu"
            font.pixelSize: Theme.fontSizeDisplay
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
                PawTools.createActionButtonModel(AssetManager.getDecorationPath("tree", 0),
                                           "info",
                                           true,
                                           function() {logText.text += "Action: Déplacer\n"}),
                PawTools.createActionButtonModel(AssetManager.getDecorationPath("tree", 1),
                                           "explorer",
                                           true,
                                           function() {logText.text += "Action: Explorer\n"}),
                PawTools.createActionButtonModel(AssetManager.getDecorationPath("tree", 2),
                                           "go home",
                                           true,
                                           function() {logText.text += "Action: goHome\n";pawMenu.mainPad.menuToggled(false)}),
                PawTools.createActionButtonModel(AssetManager.getDecorationPath("grass", 3),
                                                 "settings",
                                                 true,
                                                 function() {logText.text += "Action: Paramètres\n"})
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
