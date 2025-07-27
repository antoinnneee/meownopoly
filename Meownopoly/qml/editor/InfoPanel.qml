import QtQuick 2.15
import QtQuick.Controls

Rectangle {
    id: infoPanel
    
    // Propriétés exposées 
    property var selectedElement: null
    property var gridManager: null
    property int totalTilesCount: 0
    
    width: 320
    height: 340
    color: "#f0f0f0"
    border.color: "#cccccc"
    border.width: 1
    radius: 5
    
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 5
        
        Text {
            text: "Éditeur de Cases - Redimensionnable"
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
        Text {
            text: "Statistiques:"
            font.bold: true
            font.pixelSize: 11
            color: "#2c3e50"
        }
        
        Text {
            text: "Tiles créés: " + totalTilesCount
            font.pixelSize: 10
            color: "#7f8c8d"
        }
        
        Rectangle {
            width: parent.width
            height: 1
            color: "#cccccc"
        }
        
        // Informations sur l'élément sélectionné
        Text {
            text: "Élément sélectionné:"
            font.bold: true
            font.pixelSize: 11
            color: "#2c3e50"
        }
        
        Column {
            width: parent.width
            spacing: 3
            
            Text {
                text: selectedElement ? 
                      ("Nom: " + (selectedElement.caseData ? selectedElement.caseData.name : "Non défini")) : 
                      "Aucun élément sélectionné"
                font.pixelSize: 9
                color: selectedElement ? "#27ae60" : "#7f8c8d"
                font.bold: selectedElement !== null
            }
            
            Text {
                text: selectedElement ? 
                      ("Type: " + getCaseTypeName(selectedElement.caseData ? selectedElement.caseData.type : -1)) : 
                      ""
                font.pixelSize: 9
                color: "#3498db"
                visible: selectedElement !== null
            }
            
            Text {
                text: selectedElement ? 
                      ("Dimensions: " + Math.round(selectedElement.width) + "×" + Math.round(selectedElement.height) + "px") : 
                      ""
                font.pixelSize: 9
                color: "#e74c3c"
                visible: selectedElement !== null
            }
            
            Text {  
                text: selectedElement ? 
                      ("Position: (" + Math.round(selectedElement.x) + ", " + Math.round(selectedElement.y) + ")") : 
                      ""
                font.pixelSize: 9
                color: "#f39c12"
                visible: selectedElement !== null
            }
            
            Text {
                text: selectedElement && gridManager ? 
                      ("Grille: " + Math.round(selectedElement.width / gridManager.gridSize) + "×" + 
                       Math.round(selectedElement.height / gridManager.gridSize) + " cellules") : 
                      ""
                font.pixelSize: 9
                color: "#9b59b6"
                visible: selectedElement !== null && gridManager !== null
            }
            
            Text {
                text: selectedElement ? 
                      ("Position grille: (" + selectedElement.gridRelativePositionX + ", " + 
                       selectedElement.gridRelativePositionY + ")") : 
                      ""
                font.pixelSize: 9
                color: "#1abc9c"
                visible: selectedElement !== null
            }
        }
        
        Rectangle {
            width: parent.width
            height: 1
            color: "#cccccc"
            visible: selectedElement !== null
        }
        
        // Paramètres de grille
        Text {
            text: "Paramètres de grille:"
            font.bold: true
            font.pixelSize: 11 
            color: "#2c3e50"
        }
        
        Column {
            width: parent.width
            spacing: 2
            
            Text {
                text: gridManager ? 
                      ("Taille: " + gridManager.gridSize + "px | Snap: " + 
                       (gridManager.snapToGrid ? "ACTIVÉ" : "DÉSACTIVÉ")) : 
                      "GridManager non disponible"
                font.pixelSize: 9
                color: "#7f8c8d"
            }
            
            Text {
                text: gridManager ? 
                      ("Mode redimensionnement: " + (gridManager.resizeMode ? "ACTIF" : "INACTIF")) : 
                      ""
                font.pixelSize: 9
                color: gridManager && gridManager.resizeMode ? "#e67e22" : "#7f8c8d"
                visible: gridManager !== null
            }
            
            Text {
                text: gridManager ? 
                      ("Opacité grille: " + Math.round(gridManager.gridOpacity * 100) + "%") : 
                      ""
                font.pixelSize: 9
                color: "#95a5a6"
                visible: gridManager !== null
            }
        }
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
            from: 1.0
            to: 0.7
            duration: 100
        }
        PropertyAnimation {
            target: infoPanel
            property: "opacity"
            from: 0.7
            to: 1.0
            duration: 100
        }
    }
    
    // Fonction publique pour déclencher l'animation de mise à jour
    function triggerUpdateAnimation() {
        selectionUpdateAnimation.start()
    }
    
    // Observer les changements de sélection
    onSelectedElementChanged: {
        if (selectedElement) {
            triggerUpdateAnimation()
        }
    }
} 