import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import Case
import "."
import Player

Item {
    id: ownershipIndicator


    // Propriété pour changer la couleur
    property color ribbonColor: "#7f8c8d"
    onRibbonColorChanged: ribbonCanvas.requestPaint()
    width: 60  // Taille fixe pour le ruban
    height: 60
    anchors {
        bottom: parent.bottom
        left: parent.left
    }
    z: 3  // Au-dessus des autres éléments

    // Partie principale du ruban (triangle)
    Canvas {
        id: ribbonCanvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            
            // Couleur du ruban (sera mise à jour dynamiquement)
            ctx.fillStyle = ribbonColor;
            
            // Dessiner le triangle du ruban
            ctx.beginPath();
            ctx.moveTo(0, height);           // Coin bas-gauche
            ctx.lineTo(width * 0.7, height);  // Base du triangle
            ctx.lineTo(0, height * 0.3);     // Coin haut-gauche
            ctx.closePath();
            ctx.fill();
            
            // Ombre/bordure pour l'effet de profondeur
            ctx.strokeStyle = Qt.darker(ctx.fillStyle, 1.3);
            ctx.lineWidth = 1;
            ctx.stroke();
            
            // Effet de pli du ruban (ligne plus foncée)
            ctx.beginPath();
            ctx.moveTo(width * 0.5, height);
            ctx.lineTo(0, height * 0.5);
            ctx.strokeStyle = Qt.darker(ctx.fillStyle, 1.5);
            ctx.lineWidth = 2;
            ctx.stroke();
        }

        
        // Fonction pour mettre à jour la couleur
        function updateColor(newColor) {
            ribbonColor = newColor;
            requestPaint();
        }
    }
    
    // Effet de brillance pour rendre le ruban plus réaliste
    Rectangle {
        id: gloss
        width: parent.width * 0.3
        height: parent.height * 0.3
        anchors {
            left: parent.left
            bottom: parent.bottom
            leftMargin: 2
            bottomMargin: parent.height * 0.6
        }
        color: "white"
        opacity: 0.2
        radius: 2
        rotation: -30
    }
    
    // Fonction publique pour changer la couleur
    function setOwnerColor(color) {
        ribbonCanvas.updateColor(color);
    }
}
