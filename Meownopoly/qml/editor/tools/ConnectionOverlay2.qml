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
    property real startY: fromElement ? fromElement.globalCenterY : 200
    property real endY: toElement ? toElement.globalCenterY : 200
    property int lineWith:20
    
    anchors.fill: parent
    z: 2000
    
    ShapePath {
        strokeColor: "#96e78383"
        strokeWidth: 4
        capStyle: ShapePath.RoundCap
        fillGradient: LinearGradient {
            GradientStop { position: 0.0; color: "red" }
            GradientStop { position: 1.0; color: "blue" }
        }
        PathPolyline{
            path: [
                Qt.point(connectionOverlay.startX - lineWith/2, connectionOverlay.startY - lineWith/2),
                Qt.point(connectionOverlay.endX - lineWith/2, connectionOverlay.endY - lineWith/2),
                Qt.point(connectionOverlay.endX + lineWith/2, connectionOverlay.endY + lineWith/2),
                Qt.point(connectionOverlay.startX + lineWith/2, connectionOverlay.startY + lineWith/2)
            ]
        }
    }
}
