import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Game
import Case
import CaseRestArea
import "tools"

Rectangle {
    id: root

    color: "lightblue"
    anchors.fill: parent
    border.width: 0
    
    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        anchors.fill: parent
        mmSize: 20
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
    }
    
    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: parent

        SnapableCaseTile{
            id: caseTile1
            x: 100
            y: 100
            width: 100
            height: 100
            
            // Configuration explicite du gridManager
            gridManager: editorGrid
            
            // Sélectionner cet élément par défaut pour voir les poignées
            Component.onCompleted: {
                isSelected = true
                console.log("CaseTile1 - isSelected:", isSelected, "isResizable:", isResizable)
                console.log("CaseTile1 - gridManager:", gridManager)
            }
            
            caseData: CaseRestArea{
                type: Case.CS_RestArea
                name: "Le coin du lit"
                position: 1
                family: CaseRestArea.FT_ORANGE
            }
            
            // Gestion de sélection exclusive
            onElementClicked: function(element) {
                console.log("CaseTile1 cliqué, sélection:", element.isSelected)
                // Désélectionner les autres
                caseTile2.deselect()
                caseTile3.deselect()
            }
        }
        
        SnapableCaseTile{
            id: caseTile2
            x: 250
            y: 150
            width: 80
            height: 120
            gridManager: editorGrid
            caseData: CaseRestArea{
                type: Case.CS_RestArea
                name: "Zone de repos 2"
                position: 2
                family: CaseRestArea.FT_BLUE
            }
            
            onElementClicked: function(element) {
                console.log("CaseTile2 cliqué, sélection:", element.isSelected)
                caseTile1.deselect()
                caseTile3.deselect()
            }
        }
        
        SnapableCaseTile{
            id: caseTile3
            x: 400
            y: 80
            width: 120
            height: 80
            
            // Configuration explicite du gridManager
            gridManager: editorGrid
            
            caseData: CaseRestArea{
                type: Case.CS_RestArea
                name: "Petit coin"
                position: 3
                family: CaseRestArea.FT_GREEN
            }
            
            onElementClicked: function(element) {
                console.log("CaseTile3 cliqué, sélection:", element.isSelected)
                caseTile1.deselect()
                caseTile2.deselect()
            }
        }
    }
    
    // Panneau d'information sur l'élément sélectionné
    Rectangle {
        id: infoPanel
        width: 320
        height: 240
        color: "#f0f0f0"
        border.color: "#cccccc"
        border.width: 1
        radius: 5
        
        anchors {
            top: parent.top
            left: parent.left
            margins: 10
        }
        
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5
            
            Text {
                text: "Éditeur de Cases - Redimensionnable"
                font.bold: true
                font.pixelSize: 14
            }
            
            Text {
                text: "Instructions:"
                font.bold: true
                font.pixelSize: 12
            }
            
            Text {
                text: "• Cliquez pour sélectionner une case"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                width: parent.width
            }
            
            Text {
                text: "• Glissez les poignées bleues pour redimensionner"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                width: parent.width
            }
            
            Text {
                text: "• Le redimensionnement s'aligne sur la grille (" + editorGrid.gridSize + "px)"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                width: parent.width
            }
            
            Text {
                text: "• Glissez la case pour la déplacer"
                font.pixelSize: 10
                wrapMode: Text.WordWrap
                width: parent.width
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: "#cccccc"
            }
            
            Text {
                text: "État de l'élément sélectionné:"
                font.bold: true
                font.pixelSize: 11
                color: "#666666"
            }
            
            Text {
                text: "Case 1 - Sélectionnée: " + (caseTile1.isSelected ? "OUI" : "NON")
                font.pixelSize: 9
                color: caseTile1.isSelected ? "#2196F3" : "#666666"
            }
            
            Text {
                text: "Dimensions: " + Math.round(caseTile1.width) + "×" + Math.round(caseTile1.height) + "px"
                font.pixelSize: 9
                color: caseTile1.isSelected ? "#2196F3" : "#666666"
                visible: caseTile1.isSelected
            }
            
            Text {  
                text: "Position: (" + Math.round(caseTile1.x) + ", " + Math.round(caseTile1.y) + ")"
                font.pixelSize: 9
                color: caseTile1.isSelected ? "#2196F3" : "#666666"
                visible: caseTile1.isSelected
            }
            
            Text {
                text: "Grille: " + Math.round(caseTile1.width / editorGrid.gridSize) + "×" + Math.round(caseTile1.height / editorGrid.gridSize) + " cellules"
                font.pixelSize: 9
                color: caseTile1.isSelected ? "#2196F3" : "#666666"
                visible: caseTile1.isSelected
            }
            
            Rectangle {
                width: parent.width
                height: 1
                color: "#cccccc"
            }
            
            Text {
                text: "Paramètres de grille:"
                font.bold: true
                font.pixelSize: 11
                color: "#666666"
            }
            
            Text {
                text: "Taille: " + editorGrid.gridSize + "px | Snap: " + (editorGrid.snapToGrid ? "ACTIVÉ" : "DÉSACTIVÉ")
                font.pixelSize: 9
                color: "#666666"
            }
            
            Text {
                text: "Mode redimensionnement: " + (editorGrid.resizeMode ? "ACTIF" : "INACTIF")
                font.pixelSize: 9
                color: editorGrid.resizeMode ? "#FF6B35" : "#666666"
            }
        }
    }
    
    // Panneau de contrôle de la grille (composant séparé)
    GridControlPanel {
        id: gridControls
        anchors.fill: parent
        gridManager: editorGrid
        showControlPanel: true
        showInfoPanel: true
    }
}
