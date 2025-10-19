import QtQuick 2.15
import QtQuick.Shapes
import "../grid"

Shape {
    id: linkPreviewCursor
    
    // Propriétés requises
    required property var sourceElement
    required property real mouseX
    required property real mouseY
    required property GridManager gridManager
    
    
    // Propriétés pour le style du lien
    property color linkColor: "#4A9FFF"  // Bleu par défaut
    property color linkColorCase: "#4CAF50"  // Vert pour les cases
    property color linkColorDecoration: "#9C27B0"  // Violet pour les décorations
    property int lineWidth: 8
    property bool isHoveringTarget: false
    property var hoveredElement: null
    
    // Propriétés calculées pour les positions
    property real startX: sourceElement ? sourceElement.globalCenterX : 0
    property real endX: mouseX
    property real startY: sourceElement ? sourceElement.globalCenterY : 0
    property real endY: mouseY
    
    
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
    
    // Couleur basée sur l'état de survol et le type d'élément
    property color currentColor: {
        if (!isHoveringTarget) return linkColor
        
        // Déterminer le type d'élément survolé
        if (hoveredElement) {
            // Vérifier si c'est une case ou une décoration
            // CaseTile = 0, DecorationTile = 1 selon ItemSnapable.h
            if (hoveredElement.type === 0) {
                return linkColorCase  // Vert pour les cases
            } else if (hoveredElement.type === 1) {
                return linkColorDecoration  // Violet pour les décorations
            }
        }
        return linkColor  // Bleu par défaut
    }
    
    z: 15000 // Au-dessus de tout
    
    
    // Animation de pulsation pour indiquer que c'est temporaire
    SequentialAnimation {
        id: pulseAnimation
        running: true
        loops: Animation.Infinite
        
        NumberAnimation {
            target: linkPreviewCursor
            property: "opacity"
            from: 0.7
            to: 1.0
            duration: 1000
            easing.type: Easing.InOutQuad
        }
        
        NumberAnimation {
            target: linkPreviewCursor
            property: "opacity"
            from: 1.0
            to: 0.7
            duration: 1000
            easing.type: Easing.InOutQuad
        }
    }
    
    ShapePath {
        id: linkPath
        strokeColor: currentColor
        strokeWidth: 2
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        fillGradient: LinearGradient {
            x1: linkPreviewCursor.startX
            y1: linkPreviewCursor.startY
            x2: linkPreviewCursor.endX
            y2: linkPreviewCursor.endY
            GradientStop { position: 0.0; color: Qt.rgba(currentColor.r, currentColor.g, currentColor.b, 0.3) }
            GradientStop { position: 1.0; color: Qt.rgba(currentColor.r, currentColor.g, currentColor.b, 0.1) }
        }
        fillRule: ShapePath.WindingFill
        
        PathPolyline {
            path: [
                Qt.point(linkPreviewCursor.startX + linkPreviewCursor.perpX * linkPreviewCursor.halfWidth, 
                         linkPreviewCursor.startY + linkPreviewCursor.perpY * linkPreviewCursor.halfWidth),
                Qt.point(linkPreviewCursor.endX + linkPreviewCursor.perpX * linkPreviewCursor.halfWidth, 
                         linkPreviewCursor.endY + linkPreviewCursor.perpY * linkPreviewCursor.halfWidth),
                Qt.point(linkPreviewCursor.endX - linkPreviewCursor.perpX * linkPreviewCursor.halfWidth, 
                         linkPreviewCursor.endY - linkPreviewCursor.perpY * linkPreviewCursor.halfWidth),
                Qt.point(linkPreviewCursor.startX - linkPreviewCursor.perpX * linkPreviewCursor.halfWidth, 
                         linkPreviewCursor.startY - linkPreviewCursor.perpY * linkPreviewCursor.halfWidth),
                Qt.point(linkPreviewCursor.startX + linkPreviewCursor.perpX * linkPreviewCursor.halfWidth, 
                         linkPreviewCursor.startY + linkPreviewCursor.perpY * linkPreviewCursor.halfWidth)
            ]
        }
    }
    
    // Cercle à l'extrémité pour indiquer la destination
    ShapePath {
        id: endCircle
        fillColor: currentColor
        strokeColor: Qt.lighter(currentColor, 1.2)
        strokeWidth: 2
        
        PathAngleArc {
            centerX: linkPreviewCursor.endX
            centerY: linkPreviewCursor.endY
            radiusX: 12
            radiusY: 12
            sweepAngle: 360
        }
    }
    
    
    // Fonction pour déclencher l'animation de confirmation
    function showLinkCreated() {
    }
    
    // Fonction pour mettre à jour l'état de survol
    function updateHoverState(hovering, element) {
        isHoveringTarget = hovering
        hoveredElement = element
    }
}
