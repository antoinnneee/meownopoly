import QtQuick 2.15
import QtQuick.Shapes
import theme
import "../grid"

/**
 * Prévisualisation du polygone pendant le dessin
 * Affiche les points déjà placés et une ligne vers la position actuelle de la souris
 */
Item {
    id: root
    
    // Propriétés requises
    required property GridManager gridManager
    
    // Points du polygone en cours de dessin (coordonnées de grille)
    property var points: []
    
    // Compteur pour forcer la mise à jour (les tableaux ne sont pas réactifs nativement)
    property int pointsVersion: 0
    
    // Position actuelle de la souris (coordonnées de grille)
    property real mouseGridX: 0
    property real mouseGridY: 0
    
    // Couleur de la zone
    property color zoneColor: "#FF5722"
    property color strokeColor: Qt.darker(zoneColor, 1.3)
    
    // Visible seulement si on a au moins un point
    visible: points.length > 0
    
    // Remplir le parent (workArea)
    anchors.fill: parent
    
    // Fonction pour définir les points et forcer la mise à jour
    function setPoints(newPoints) {
        points = newPoints
        pointsVersion++
    }
    
    // Convertir les points en pixels
    function getPointsPixel() {
        // Dépendance sur pointsVersion pour forcer le recalcul
        var version = pointsVersion
        var pixelPoints = []
        for (var i = 0; i < points.length; i++) {
            pixelPoints.push(Qt.point(
                points[i].x * gridManager.gridSize,
                points[i].y * gridManager.gridSize
            ))
        }
        return pixelPoints
    }
    
    // Obtenir le chemin complet incluant la position de la souris
    function getPreviewPath() {
        var path = getPointsPixel()
        // Ajouter la position de la souris comme point suivant
        if (path.length > 0) {
            path.push(Qt.point(
                mouseGridX * gridManager.gridSize,
                mouseGridY * gridManager.gridSize
            ))
        }
        return path
    }
    
    // Shape pour le polygone en cours
    Shape {
        id: previewShape
        anchors.fill: parent
        z: 10000  // Au-dessus de tout
        
        // Forcer la mise à jour quand pointsVersion change
        property int updateTrigger: root.pointsVersion
        
        // Lignes du polygone existant
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: 2
            fillColor: Qt.rgba(root.zoneColor.r, root.zoneColor.g, root.zoneColor.b, 0.1)
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            
            PathPolyline {
                id: mainPath
                path: {
                    // Dépendance sur plusieurs propriétés pour forcer la mise à jour
                    var trigger = previewShape.updateTrigger
                    var mx = root.mouseGridX
                    var my = root.mouseGridY
                    return root.getPreviewPath()
                }
            }
        }
        
        // Ligne pointillée de fermeture (de la souris au premier point)
        ShapePath {
            strokeColor: root.strokeColor
            strokeWidth: 1
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 4]
            
            startX: root.mouseGridX * root.gridManager.gridSize
            startY: root.mouseGridY * root.gridManager.gridSize
            
            PathLine {
                x: root.points.length > 0 ? root.points[0].x * root.gridManager.gridSize : 0
                y: root.points.length > 0 ? root.points[0].y * root.gridManager.gridSize : 0
            }
        }
    }
    
    // Points de contrôle (cercles sur chaque point)
    Repeater {
        model: root.points.length
        
        Rectangle {
            visible: index < root.points.length
            width: 10
            height: 10
            radius: 5
            color: root.zoneColor
            border.color: "white"
            border.width: 2
            z: 10001
            
            x: (index < root.points.length ? root.points[index].x : 0) * root.gridManager.gridSize - width / 2
            y: (index < root.points.length ? root.points[index].y : 0) * root.gridManager.gridSize - height / 2
        }
    }
    
    // Point de prévisualisation à la position de la souris
    Rectangle {
        visible: root.points.length > 0
        width: 10
        height: 10
        radius: 5
        color: Qt.lighter(root.zoneColor, 1.3)
        border.color: "white"
        border.width: 2
        opacity: 0.7
        z: 10001
        
        x: root.mouseGridX * root.gridManager.gridSize - width / 2
        y: root.mouseGridY * root.gridManager.gridSize - height / 2
    }
    
    // Indicateur du nombre de points
    Rectangle {
        visible: root.points.length > 0
        color: Qt.rgba(0, 0, 0, 0.7)
        radius: Theme.radiusS
        width: pointCountText.width + 16
        height: pointCountText.height + 8
        z: 10002
        
        x: root.mouseGridX * root.gridManager.gridSize + 15
        y: root.mouseGridY * root.gridManager.gridSize - 25
        
        Text {
            id: pointCountText
            anchors.centerIn: parent
            text: root.points.length + " point" + (root.points.length > 1 ? "s" : "") + 
                  (root.points.length >= 3 ? " (clic droit pour terminer)" : " (min. 3)")
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
        }
    }
}
