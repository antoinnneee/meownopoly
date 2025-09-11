import QtQuick 2.15
import QtQuick.Controls

Rectangle {
    id: infoPanel
    
    // Propriétés exposées
    property var gridManager: null
    property int totalTilesCount: 0
    
    width: 320
    height: 450
    color: "#f0f0f0"
    border.color: "#cccccc"
    border.width: 1
    radius: 5
    opacity: 0.8
    
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5
        
        Text {
            text: "Éditeur de Cases"
            font.bold: true
            font.pixelSize: 14
            color: "#2c3e50"
        }
        
        Rectangle {
            width: parent.width
            height: 1
            color: "#3498db"
        }
        
        Text {
            text: "Instructions:"
            font.bold: true
            font.pixelSize: 12
            color: "#34495e"
        }
        
        // Instructions d'utilisation
        Column {
            width: parent.width
            spacing: 2
            
            InstructionText {
                text: "• Cliquez pour sélectionner une case"
            }
            
            InstructionText {
                text: "• Glissez les poignées bleues pour redimensionner"
            }
            
            InstructionText {
                text: "• Le redimensionnement s'aligne sur la grille (" + 
                      (gridManager ? gridManager.gridSize + "px" : "N/A") + ")"
            }
            
            InstructionText {
                text: "• Glissez la case pour la déplacer"
            }
            
            InstructionText {
                text: "• Ctrl + molette pour zoomer la grille"
            }
        }
        
        Rectangle {
            width: parent.width
            height: 1
            color: "#cccccc"
        }
        
        // Statistiques générales
        
        // Informations sur l'élément sélectionné
        Text {
            text: "Élément sélectionné:"
            font.bold: true
            font.pixelSize: 11
            color: "#2c3e50"
        }


        // Paramètres de grille
    }
    
    // Composant réutilisable pour les textes d'instruction
    component InstructionText: Text {
        font.pixelSize: 10
        wrapMode: Text.WordWrap
        width: parent.width
        color: "#7f8c8d"
    }
    
    // Fonction utilitaire pour obtenir le nom du type de case
    function getCaseTypeName(caseType) {
        switch(caseType) {
            case 0: return "Kibble Dispenser"
            case 1: return "Zone de repos"
            case 2: return "Boîte en carton"
            case 3: return "Herbe à chat"
            case 4: return "Prison"
            case 5: return "Aller en prison"
            case 6: return "Chatière"
            case 7: return "Sieste gratuite"
            case 8: return "Appareil électronique"
            case 9: return "Taxe"
            default: return "Type inconnu"
        }
    }
    
    // Animation de mise à jour lors de la sélection
    SequentialAnimation {
        id: selectionUpdateAnimation
        
        PropertyAnimation {
            target: infoPanel
            property: "opacity"
            from: 0.8
            to: 0.6
            duration: 100
        }
        PropertyAnimation {
            target: infoPanel
            property: "opacity"
            from: 0.6
            to: 0.8
            duration: 100
        }
    }

} 
