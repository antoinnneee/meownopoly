import QtQuick 2.15
import QtQuick.Controls

/**
 * GridManager avec animation fluide de zoom
 * 
 * Features:
 * - Zoom instantané pour la réactivité (gridSize)
 * - Animation fluide après stabilisation (animatedGridSize) 
 * - Délai configurable avant animation (150ms par défaut)
 * - Snap basé sur la grille logique, pas l'animation
 * 
 * Usage pour personnaliser l'animation:
 *   gridManager.setZoomAnimationSettings(300, 100) // 300ms duration, 100ms delay
 */
Rectangle {
    id: gridControlPanel
    width: 200
    height: 250
    color: "#f0f0f0"
    border.color: "#cccccc"
    border.width: 1
    radius: 5
    visible: false
    required property GridManager gridManager
    required property int mmSize
    required property bool showGrid
    required property bool snapToGrid
    required property real gridOpacity

    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        Text {
            text: "Paramètres de grille"
            font.bold: true
        }
        
        Row {
            spacing: 10
            Text { text: "Taille:" }
            SpinBox {
                from: 5
                to: 200
                stepSize: 5
                value: gridManager.mmSize
                onValueChanged: mmSize = value
            }
        }
        
        Row {
            spacing: 10
            Text { text: "Afficher grille:" }
            CheckBox {
                checked: gridManager.showGrid
                onCheckedChanged: showGrid = checked
            }
        }
        
        Row {
            spacing: 10
            Text { text: "Snap à la grille:" }
            CheckBox {
                checked: gridManager.snapToGrid
                onCheckedChanged: snapToGrid = checked
            }
        }
        
        Row {
            spacing: 10
            Text { text: "Opacité:" }
            Slider {
                from: 0.1
                to: 1.0
                value: gridManager.gridOpacity
                onValueChanged: gridOpacity = value
            }
        }
    }
}
