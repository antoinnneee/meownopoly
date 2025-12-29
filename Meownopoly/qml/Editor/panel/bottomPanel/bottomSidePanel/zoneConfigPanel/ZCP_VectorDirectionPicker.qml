import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

/**
 * VectorDirectionPicker - Composant intuitif pour configurer un vecteur 2D
 * 
 * Affiche un cercle avec une flèche qui peut être dirigée en cliquant/glissant.
 * Le vecteur résultant est normalisé (longueur = 1) ou peut être mis à zéro.
 */
Item {
    id: root
    
    // Propriétés du vecteur
    property real directionX: 0.0
    property real directionY: 0.0
    
    // Propriétés de style
    property color backgroundColor: "#1a1a1a"
    property color circleColor: "#333333"
    property color arrowColor: "#5cb85c"
    property color gridColor: "#444444"
    property color highlightColor: "#7bd97f"
    property int circleSize: 100
    
    // Propriété calculée: angle en radians
    readonly property real angle: Math.atan2(directionY, directionX)
    readonly property real magnitude: Math.sqrt(directionX * directionX + directionY * directionY)
    readonly property bool hasDirection: magnitude > 0.01
    
    // Signaux
    signal directionChanged(real x, real y)
    
    implicitWidth: circleSize + 20
    implicitHeight: circleSize + 60
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        
        // Zone circulaire interactive
        Rectangle {
            id: circleContainer
            Layout.alignment: Qt.AlignHCenter
            width: root.circleSize
            height: root.circleSize
            radius: width / 2
            color: root.backgroundColor
            border.color: mouseArea.containsMouse || mouseArea.pressed ? root.highlightColor : root.circleColor
            border.width: 2
            
            Behavior on border.color {
                ColorAnimation { duration: 150 }
            }
            
            // Grille de fond (axes)
            Canvas {
                id: gridCanvas
                anchors.fill: parent
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    
                    var centerX = width / 2
                    var centerY = height / 2
                    var radius = width / 2 - 4
                    
                    ctx.strokeStyle = root.gridColor
                    ctx.lineWidth = 1
                    ctx.globalAlpha = 0.5
                    
                    // Axe horizontal
                    ctx.beginPath()
                    ctx.moveTo(centerX - radius, centerY)
                    ctx.lineTo(centerX + radius, centerY)
                    ctx.stroke()
                    
                    // Axe vertical
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY - radius)
                    ctx.lineTo(centerX, centerY + radius)
                    ctx.stroke()
                    
                    // Cercles concentriques
                    ctx.globalAlpha = 0.3
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, radius * 0.5, 0, 2 * Math.PI)
                    ctx.stroke()
                }
            }
            
            // Flèche du vecteur
            Canvas {
                id: arrowCanvas
                anchors.fill: parent
                
                property real arrowX: root.directionX
                property real arrowY: root.directionY
                
                onArrowXChanged: requestPaint()
                onArrowYChanged: requestPaint()
                
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    
                    if (!root.hasDirection) return
                    
                    var centerX = width / 2
                    var centerY = height / 2
                    var radius = width / 2 - 2  // Flèche plus longue
                    
                    // Normaliser le vecteur pour l'affichage
                    var mag = root.magnitude
                    var normX = root.directionX / mag
                    var normY = root.directionY / mag
                    
                    var endX = centerX + normX * radius
                    var endY = centerY + normY * radius
                    
                    // Dessiner la ligne principale
                    ctx.strokeStyle = root.arrowColor
                    ctx.lineWidth = 3
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY)
                    ctx.lineTo(endX, endY)
                    ctx.stroke()
                    
                    // Pointe de la flèche
                    var arrowSize = 12
                    var angle = Math.atan2(normY, normX)
                    var arrowAngle = Math.PI / 6  // 30 degrés
                    
                    ctx.fillStyle = root.arrowColor
                    ctx.beginPath()
                    ctx.moveTo(endX, endY)
                    ctx.lineTo(
                        endX - arrowSize * Math.cos(angle - arrowAngle),
                        endY - arrowSize * Math.sin(angle - arrowAngle)
                    )
                    ctx.lineTo(
                        endX - arrowSize * Math.cos(angle + arrowAngle),
                        endY - arrowSize * Math.sin(angle + arrowAngle)
                    )
                    ctx.closePath()
                    ctx.fill()
                    
                    // Point central
                    ctx.fillStyle = root.highlightColor
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, 4, 0, 2 * Math.PI)
                    ctx.fill()
                }
            }
            
            // Zone de clic/drag
            MouseArea {
                id: mouseArea
                anchors.fill: parent
                hoverEnabled: true
                preventStealing: true
                
                function updateDirection(mouseX, mouseY) {
                    var centerX = width / 2
                    var centerY = height / 2
                    
                    var dx = mouseX - centerX
                    var dy = mouseY - centerY
                    
                    // Normaliser le vecteur
                    var mag = Math.sqrt(dx * dx + dy * dy)
                    if (mag > 5) {  // Seuil pour éviter les mouvements trop petits
                        root.directionX = dx / mag
                        root.directionY = dy / mag
                        root.directionChanged(root.directionX, root.directionY)
                    }
                }
                
                onPressed: function(mouse) {
                    updateDirection(mouse.x, mouse.y)
                }
                
                onPositionChanged: function(mouse) {
                    if (pressed) {
                        updateDirection(mouse.x, mouse.y)
                    }
                }
            }
        }
        
        // Affichage des valeurs
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 12
            
            // Valeur X
            RowLayout {
                spacing: 4
                Text {
                    text: "X:"
                    color: "#888888"
                    font.pixelSize: 11
                }
                Text {
                    text: root.directionX.toFixed(2)
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 35
                }
            }
            
            // Valeur Y
            RowLayout {
                spacing: 4
                Text {
                    text: "Y:"
                    color: "#888888"
                    font.pixelSize: 11
                }
                Text {
                    text: root.directionY.toFixed(2)
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                    Layout.preferredWidth: 35
                }
            }
        }
        
        // Bouton Reset
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            width: 60
            height: 22
            radius: 4
            color: resetArea.pressed ? "#444444" : (resetArea.containsMouse ? "#3a3a3a" : "#2a2a2a")
            border.color: "#555555"
            border.width: 1
            
            Text {
                anchors.centerIn: parent
                text: "Reset"
                color: "#cccccc"
                font.pixelSize: 10
            }
            
            MouseArea {
                id: resetArea
                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    root.directionX = 0
                    root.directionY = 0
                    root.directionChanged(0, 0)
                }
            }
        }
    }
    
    // Fonction pour définir la direction depuis l'extérieur
    function setDirection(x, y) {
        directionX = x
        directionY = y
    }
}
