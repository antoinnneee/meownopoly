import QtQuick
import QtQuick.Shapes

Shape {
    id: connectionOverlay
    // Overlay de connexion en zigzag arrondi

    // Propriétés requises
    required property var fromElement
    required property var toElement
    
    property bool selected: false

    // Propriétés calculées pour les positions
    property real startX: fromElement ? fromElement.globalCenterX : 0
    property real endX: toElement ? toElement.globalCenterX : 0
    property real startY: fromElement ? fromElement.globalCenterY : 0
    property real endY: toElement ? toElement.globalCenterY : 0
    property int lineWidth: 8
    
    // Calcul de la direction et des vecteurs perpendiculaires
    property real deltaX: endX - startX
    property real deltaY: endY - startY
    property real lineLength: Math.sqrt(deltaX * deltaX + deltaY * deltaY)
    
    // Vecteur unitaire de la ligne
    property real unitX: lineLength > 0 ? deltaX / lineLength : 1
    property real unitY: lineLength > 0 ? deltaY / lineLength : 0
    
    // Vecteur perpendiculaire unitaire (rotation 90°) pour le zigzag
    property real perpX: -unitY
    property real perpY: unitX

    // Propriétés pour le zigzag dynamique
    property int zigzagCount: Math.max(1, Math.floor(lineLength / 120))
    property real zigzagAmplitude: lineLength * 0.02
    property real curveRadius: 5000

    // Fonction pour générer les points du zigzag
    function generateZigzagPath() {
        var points = []
        var segments = zigzagCount * 2 // Nombre de segments (2 par zigzag)
        
        // Point de départ
        points.push({x: startX, y: startY})
        
        // Générer les points de zigzag
        for (var i = 1; i <= segments; i++) {
            var t = i / (segments + 1) // Position le long de la ligne (0 à 1)
            var baseX = startX + t * deltaX
            var baseY = startY + t * deltaY
            
            // Alterner de chaque côté
            var side = (i % 2 === 0) ? 1 : -1
            var offsetX = perpX * zigzagAmplitude * side
            var offsetY = perpY * zigzagAmplitude * side
            
            points.push({
                x: baseX + offsetX,
                y: baseY + offsetY
            })
        }

        // Point de fin
        points.push({x: endX, y: endY})
        
        return points
    }

    // Fonction pour évaluer un point sur une courbe de Bézier cubique
    function bezierPoint(t, p0x, p0y, c1x, c1y, c2x, c2y, p1x, p1y) {
        var mt = 1 - t
        var mt2 = mt * mt
        var mt3 = mt2 * mt
        var t2 = t * t
        var t3 = t2 * t
        
        return {
            x: mt3 * p0x + 3 * mt2 * t * c1x + 3 * mt * t2 * c2x + t3 * p1x,
            y: mt3 * p0y + 3 * mt2 * t * c1y + 3 * mt * t2 * c2y + t3 * p1y
        }
    }

    // Fonction pour générer tous les points de la courbe avec Bézier
    function generateSmoothCurvePath() {
        var points = generateZigzagPath()
        if (points.length < 2) return []
        
        var result = []
        var stepsPerSegment = 30 // Nombre de points par segment de courbe
        
        // Premier point
        result.push(Qt.point(points[0].x, points[0].y))
        
        // Pour chaque segment, générer les points de la courbe de Bézier
        for (var i = 1; i < points.length; i++) {
            var p0 = points[i - 1]
            var p1 = points[i]
            
            // Calculer la distance et direction
            var dx = p1.x - p0.x
            var dy = p1.y - p0.y
            var dist = Math.sqrt(dx * dx + dy * dy)
            
            if (dist === 0) continue
            
            // Points de contrôle pour créer des courbes plus arrondies
            // On utilise les points adjacents pour calculer la tangente
            var c1x, c1y, c2x, c2y
            
            // Facteur de tension pour les courbes (basé sur curveRadius)
            // Plus le curveRadius est grand, plus les courbes sont douces
            var tension = Math.min(curveRadius / 100, 0.5)
            
            // Point de contrôle 1 (sortie de p0)
            if (i > 1) {
                // Calculer la tangente en utilisant le point précédent
                var pPrev = points[i - 2]
                var tanX = p1.x - pPrev.x
                var tanY = p1.y - pPrev.y
                var tanLen = Math.sqrt(tanX * tanX + tanY * tanY)
                if (tanLen > 0) {
                    tanX /= tanLen
                    tanY /= tanLen
                }
                c1x = p0.x + tanX * dist * tension
                c1y = p0.y + tanY * dist * tension
            } else {
                // Premier segment : direction simple
                c1x = p0.x + dx * tension
                c1y = p0.y + dy * tension
            }
            
            // Point de contrôle 2 (entrée vers p1)
            if (i < points.length - 1) {
                // Calculer la tangente en utilisant le point suivant
                var pNext = points[i + 1]
                var tanX = pNext.x - p0.x
                var tanY = pNext.y - p0.y
                var tanLen = Math.sqrt(tanX * tanX + tanY * tanY)
                if (tanLen > 0) {
                    tanX /= tanLen
                    tanY /= tanLen
                }
                c2x = p1.x - tanX * dist * tension
                c2y = p1.y - tanY * dist * tension
            } else {
                // Dernier segment : direction simple
                c2x = p1.x - dx * tension
                c2y = p1.y - dy * tension
            }
            
            // Générer les points intermédiaires de la courbe
            for (var step = 1; step <= stepsPerSegment; step++) {
                var t = step / stepsPerSegment
                var pt = bezierPoint(t, p0.x, p0.y, c1x, c1y, c2x, c2y, p1.x, p1.y)
                result.push(Qt.point(pt.x, pt.y))
            }
        }
        
        return result
    }

    z: (selected) ? 20000 : 10000

    // Animation du gradient
    SequentialAnimation {
        id: seqA
        PropertyAnimation {
            to: 1.
            from: 0.01
            duration: 4600
            target: gradientPath.stop1
            property: "position"
        }
        onFinished: start()
        running: true
    }

    // Chemin visible avec courbes de Bézier calculées (contour)
    ShapePath {
        id: shapePath
        strokeColor: (connectionOverlay.selected) ? "white" : "#96e78383"
        strokeWidth: 2
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        fillColor: "transparent"
        
        PathPolyline {
            path: connectionOverlay.generateSmoothCurvePath()
        }
    }
    
    // Second chemin pour le gradient (forme fermée avec épaisseur)
    ShapePath {
        id: gradientPath
        strokeColor: "transparent"
        strokeWidth: 1
        property alias stop1: stop1g
        property alias stop2: stop2g
        
        fillGradient: LinearGradient {
            id: linearGrad
            x1: connectionOverlay.startX
            y1: connectionOverlay.startY
            x2: connectionOverlay.endX
            y2: connectionOverlay.endY
            GradientStop { id: stop0g; position: 0.0; color: connectionOverlay.selected ? "#004A9FFF" : "#006DB3F2" }
            GradientStop { id: stop1g; position: 0.0; color: connectionOverlay.selected ? "#FFB565D8" : "#FF9B7EBD" }
            GradientStop { id: stop2g; position: 1.0; color: connectionOverlay.selected ? "#004A9FFF" : "#006DB3F2" }
        }
        
        fillRule: ShapePath.WindingFill
        
        PathPolyline {
            path: {
                var centerPath = connectionOverlay.generateSmoothCurvePath()
                if (centerPath.length < 2) return []
                
                var halfWidth = connectionOverlay.lineWidth / 2
                var result = []
                
                // Bord supérieur
                for (var i = 0; i < centerPath.length; i++) {
                    var p = centerPath[i]
                    var offsetX = 0
                    var offsetY = 0
                    
                    if (i === 0 && centerPath.length > 1) {
                        var next = centerPath[i + 1]
                        var dx = next.x - p.x
                        var dy = next.y - p.y
                        var len = Math.sqrt(dx * dx + dy * dy)
                        if (len > 0) {
                            offsetX = -dy / len * halfWidth
                            offsetY = dx / len * halfWidth
                        }
                    } else if (i === centerPath.length - 1 && centerPath.length > 1) {
                        var prev = centerPath[i - 1]
                        var dx = p.x - prev.x
                        var dy = p.y - prev.y
                        var len = Math.sqrt(dx * dx + dy * dy)
                        if (len > 0) {
                            offsetX = -dy / len * halfWidth
                            offsetY = dx / len * halfWidth
                        }
                    } else if (centerPath.length > 2) {
                        var prev = centerPath[i - 1]
                        var next = centerPath[i + 1]
                        
                        var dx1 = p.x - prev.x
                        var dy1 = p.y - prev.y
                        var len1 = Math.sqrt(dx1 * dx1 + dy1 * dy1)
                        
                        var dx2 = next.x - p.x
                        var dy2 = next.y - p.y
                        var len2 = Math.sqrt(dx2 * dx2 + dy2 * dy2)
                        
                        var avgDx = (len1 > 0 ? dx1 / len1 : 0) + (len2 > 0 ? dx2 / len2 : 0)
                        var avgDy = (len1 > 0 ? dy1 / len1 : 0) + (len2 > 0 ? dy2 / len2 : 0)
                        var avgLen = Math.sqrt(avgDx * avgDx + avgDy * avgDy)
                        
                        if (avgLen > 0) {
                            offsetX = -avgDy / avgLen * halfWidth
                            offsetY = avgDx / avgLen * halfWidth
                        }
                    }
                    
                    result.push(Qt.point(p.x + offsetX, p.y + offsetY))
                }
                
                // Bord inférieur (en ordre inverse)
                for (var i = centerPath.length - 1; i >= 0; i--) {
                    var p = centerPath[i]
                    var offsetX = 0
                    var offsetY = 0
                    
                    if (i === 0 && centerPath.length > 1) {
                        var next = centerPath[i + 1]
                        var dx = next.x - p.x
                        var dy = next.y - p.y
                        var len = Math.sqrt(dx * dx + dy * dy)
                        if (len > 0) {
                            offsetX = dy / len * halfWidth
                            offsetY = -dx / len * halfWidth
                        }
                    } else if (i === centerPath.length - 1 && centerPath.length > 1) {
                        var prev = centerPath[i - 1]
                        var dx = p.x - prev.x
                        var dy = p.y - prev.y
                        var len = Math.sqrt(dx * dx + dy * dy)
                        if (len > 0) {
                            offsetX = dy / len * halfWidth
                            offsetY = -dx / len * halfWidth
                        }
                    } else if (centerPath.length > 2) {
                        var prev = centerPath[i - 1]
                        var next = centerPath[i + 1]
                        
                        var dx1 = p.x - prev.x
                        var dy1 = p.y - prev.y
                        var len1 = Math.sqrt(dx1 * dx1 + dy1 * dy1)
                        
                        var dx2 = next.x - p.x
                        var dy2 = next.y - p.y
                        var len2 = Math.sqrt(dx2 * dx2 + dy2 * dy2)
                        
                        var avgDx = (len1 > 0 ? dx1 / len1 : 0) + (len2 > 0 ? dx2 / len2 : 0)
                        var avgDy = (len1 > 0 ? dy1 / len1 : 0) + (len2 > 0 ? dy2 / len2 : 0)
                        var avgLen = Math.sqrt(avgDx * avgDx + avgDy * avgDy)
                        
                        if (avgLen > 0) {
                            offsetX = avgDy / avgLen * halfWidth
                            offsetY = -avgDx / avgLen * halfWidth
                        }
                    }
                    
                    result.push(Qt.point(p.x + offsetX, p.y + offsetY))
                }
                
                // Fermer le chemin
                if (result.length > 0) {
                    result.push(result[0])
                }
                
                return result
            }
        }
    }
}

