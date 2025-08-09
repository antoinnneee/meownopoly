import QtQuick 2.15

Item {
    id: connectionOverlay
    
    // Propriétés requises
    required property var fromElement
    required property var toElement
    
    // Propriétés calculées pour les positions
    property real startX: fromElement ? fromElement.globalCenterX : 0
    property real endX: toElement ? toElement.globalCenterX : 0
    property real startY: fromElement ? fromElement.globalCenterY : 0
    property real endY: toElement ? toElement.globalCenterY : 0
    
    anchors.fill: parent
    z: 2000
    
    // Calcul de l'angle et de la longueur
    property real lineAngle: Math.atan2(endY - startY, endX - startX) * 180 / Math.PI
    property real lineLength: Math.sqrt(Math.pow(endX - startX, 2) + Math.pow(endY - startY, 2))
    
    // Rectangle avec gradient pour simuler la ligne
    Rectangle {
        width: connectionOverlay.lineLength
        height: 3
        x: connectionOverlay.startX
        y: connectionOverlay.startY - height/2
        
        transformOrigin: Item.Left
        rotation: connectionOverlay.lineAngle
        
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#FF0000" }  // Rouge au début
            GradientStop { position: 1.0; color: "#0000FF" }  // Bleu à la fin
        }
    }
}