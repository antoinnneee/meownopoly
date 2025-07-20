import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import Case
import "../case/"

Rectangle {
    id: root
    width: 1200
    height: 800
    color: "#2c3e50"
    
    // Taille standard et identique pour toutes les cases
    property real standardTileWidth: 120
    property real standardTileHeight: 160
    
    // Initialize game on component creation
    Component.onCompleted: {
        console.log("Initializing game...")
        Game.init()
        console.log("Game initialized. Total cases:", Game.listCases.length)
    }
    


    // Title
    Text {
        id: titleText
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 20
        text: "TEST BOARD 2 - 10 Cases"
        color: "#ecf0f1"
        font.pixelSize: 18
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
    }
    
    // Row pour afficher 10 cases côte à côte
    GridLayout {
        anchors.centerIn: parent
        uniformCellHeights: true
        uniformCellWidths: true
        rows: 10
        columns: 10
        // Répéter pour 10 cases seulement
        Repeater {
            id: repeater
            model: Game.listCases * 10

            delegate: CaseTile {
                width: standardTileWidth
                height: standardTileHeight
                // property int indexCase : repeater.index
                required property int index;               // Déclaration de caseData comme spécifié
                caseData: Game.listCases[index]
                
                // Debug info
                Component.onCompleted: {
                    console.log("Created CaseTile", indexCase/*, "for case:", caseData ? caseData.name : "null"*/)
                }
            }
        }
    }
} 
