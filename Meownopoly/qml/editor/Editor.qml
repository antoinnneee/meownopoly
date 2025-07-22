import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import Game
import Case
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
        gridSize: 20
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
    }
    
    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: parent
        
        // Exemple d'éléments utilisant SnapableElement
        SnapableElement {
            id: testElement1
            width: 40
            height: 40
            x: 60
            y: 60
            elementColor: "red"
            borderColor: "darkred"
            gridManager: editorGrid
            
            onElementClicked: {
                console.log("Element 1 cliqué")
            }
            
            Text {
                anchors.centerIn: parent
                text: "Test 1"
                color: "white"
                font.pixelSize: 8
            }
        }
        
        SnapableElement {
            id: testElement2
            width: 60
            height: 30
            x: 140
            y: 100
            elementColor: "blue"
            borderColor: "darkblue"
            gridManager: editorGrid
            
            onElementClicked: {
                console.log("Element 2 cliqué")
            }
            
            Text {
                anchors.centerIn: parent
                text: "Test 2"
                color: "white"
                font.pixelSize: 9
            }
        }
        
        // Élément avec apparence différente
        SnapableElement {
            id: testElement3
            width: 50
            height: 50
            x: 220
            y: 80
            elementColor: "green"
            borderColor: "darkgreen"
            borderWidth: 2
            gridManager: editorGrid
            
            onSnapCompleted: {
                console.log("Element 3 snappé à la position:", x, y)
            }
            
            Text {
                anchors.centerIn: parent
                text: "Test 3"
                color: "white"
                font.pixelSize: 8
                font.bold: true
            }
        }
        
        // --- Exemples de MapTileElement ---
        
        MapTileElement {
            id: wallTile
            x: 80
            y: 200
            tileType: "wall"
            tileId: 1
            gridManager: editorGrid
            
            onTileTypeChanged: {
                console.log("Tuile", tileId, "changée en:", newType)
            }
        }
        
        MapTileElement {
            id: doorTile
            x: 140
            y: 200
            tileType: "door"
            tileId: 2
            gridManager: editorGrid
        }
        
        MapTileElement {
            id: spawnTile
            x: 200
            y: 200
            tileType: "spawn"
            tileId: 3
            gridManager: editorGrid
        }
        
        MapTileElement {
            id: floorTile
            x: 260
            y: 200
            tileType: "floor"
            tileId: 4
            gridManager: editorGrid
        }
        
        MapTileElement {
            id: itemTile
            x: 320
            y: 200
            tileType: "item"
            tileId: 5
            gridManager: editorGrid
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
