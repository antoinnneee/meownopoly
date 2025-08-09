import QtQuick
import QtQuick.Shapes

Shape {
    id: connectionOverlay
    
    // Propriétés requises
    required property var fromElement
    required property var toElement
    
    // Propriétés calculées pour les positions
    property real startX: fromElement ? fromElement.globalCenterX : 0
    property real endX: toElement ? toElement.globalCenterX : 0
    property real startY: fromElement ? fromElement.globalCenterY : 0
    property real endY: toElement ? toElement.globalCenterY : 0
    property int lineWidth: 20
    
    // Calcul de la direction et des vecteurs perpendiculaires
    property real deltaX: endX - startX
    property real deltaY: endY - startY
    property real lineLength: Math.sqrt(deltaX * deltaX + deltaY * deltaY)
    
    // Vecteur unitaire de la ligne
    property real unitX: lineLength > 0 ? deltaX / lineLength : 1
    property real unitY: lineLength > 0 ? deltaY / lineLength : 0
    
    // Vecteur perpendiculaire unitaire (rotation 90°)
    property real perpX: -unitY
    property real perpY: unitX
    
    // Demi-largeur pour les calculs
    property real halfWidth: lineWidth / 2
    
    anchors.fill: parent
    z: 2000
    
    ShapePath {
        strokeColor: "#96e78383"
        strokeWidth: 4
        capStyle: ShapePath.RoundCap
        fillGradient: LinearGradient {
            x1: connectionOverlay.startX
            y1: connectionOverlay.startY
            x2: connectionOverlay.endX
            y2: connectionOverlay.endY
            GradientStop { position: 0.0; color: "red" }
            GradientStop { position: 1.0; color: "blue" }

        }
        fillRule: ShapePath.WindingFill
        PathPolyline{
            path: [
                Qt.point(connectionOverlay.startX + connectionOverlay.perpX * connectionOverlay.halfWidth, 
                         connectionOverlay.startY + connectionOverlay.perpY * connectionOverlay.halfWidth),
                Qt.point(connectionOverlay.endX + connectionOverlay.perpX * connectionOverlay.halfWidth, 
                         connectionOverlay.endY + connectionOverlay.perpY * connectionOverlay.halfWidth),
                Qt.point(connectionOverlay.endX - connectionOverlay.perpX * connectionOverlay.halfWidth, 
                         connectionOverlay.endY - connectionOverlay.perpY * connectionOverlay.halfWidth),
                Qt.point(connectionOverlay.startX - connectionOverlay.perpX * connectionOverlay.halfWidth, 
                         connectionOverlay.startY - connectionOverlay.perpY * connectionOverlay.halfWidth)
            ]
        }
    }
}
