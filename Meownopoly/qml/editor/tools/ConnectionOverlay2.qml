import QtQuick
import QtQuick.Shapes

Shape {
    id: connectionOverlay
    // Overlay de connexion en points

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

    property int dotLength: lineLength/50
    onDotLengthChanged: {
        console.log("dotLength changed ", dotLength)
        dotLine.pathElements = []
    }

    z: 20000
    
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

    ShapePath {
        id: dotLine
        // Couleur/épaisseur des points
        strokeColor: "white"
        strokeWidth: 3
        capStyle: ShapePath.FlatCap
        // Style pointillé pour obtenir une suite de points
        strokeStyle: ShapePath.SolidLine
        // Remplissage utilisé pour les cercles ajoutés
        fillColor: "transparent"
        // Propriétés locales pour les cercles
        property real circleRadius: 14
        // Position de départ
        startX: connectionOverlay.startX
        startY: connectionOverlay.startY
    }
    Component{
        id: inAnimation
        NumberAnimation {
            property: "radius"
            from: 0
            to: dotLine.circleRadius
            duration: 700
            easing.type: Easing.InOutQuad
        }
    }
    Component{
        id: breathAnimationComp
        Item {
            property int circleIndex: 0
            property var targetObj: null
            Timer{
                running: true
                interval: 100+circleIndex*150
                repeat: false
                onTriggered: {
                    breathAnimation.start()
                }
            }
            SequentialAnimation{
                id: breathAnimation
                loops: Animation.Infinite
                NumberAnimation {
                    properties: "radius"
                    target: targetObj
                    easing.bezierCurve: [0.25,0.102,0.549,1.13,1,1]
                    from: dotLine.circleRadius
                    to: dotLine.circleRadius*1.3
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
                PauseAnimation {
                    duration: 400
                }
                NumberAnimation {
                    properties: "radius"
                    target: targetObj
                    easing.bezierCurve: [0.332,0.135,0.534,1.14,1,1]
                    from: dotLine.circleRadius*1.3
                    to: dotLine.circleRadius
                    duration: 600
                    easing.type: Easing.InOutQuad
                }
                PauseAnimation {
                    duration: 3000
                }
            }
        }
    }
    Instantiator{
        onObjectAdded: {
            console.log("object added ",index,  object)
            if (object)dotLine.pathElements.push(object)
            
            // create a dynamic NumberAnimation for the radius
            var animation = breathAnimationComp.createObject(connectionOverlay)
            animation.targetObj = object
            animation.circleIndex = index
        }
        onObjectRemoved: {
            console.log("object removed ",index,  object)
        }

        model: dotLength
        PathAngleArc {
            id: circle
            // position régulière le long de la ligne de start->end
            property real t: dotLength > 1 ? (index / (dotLength - 1)) : 0.5
            property real radius: dotLine.circleRadius
            centerX: connectionOverlay.startX + t * connectionOverlay.deltaX
            centerY: connectionOverlay.startY + t * connectionOverlay.deltaY
            radiusX: radius
            radiusY: radius
            sweepAngle: 360
        }
    }
}
