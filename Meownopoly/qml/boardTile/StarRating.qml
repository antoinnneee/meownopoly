import QtQuick
import QtQuick.Controls

Item {
    id: root
    implicitWidth: maxStars * (starSize + spacing) - spacing
    implicitHeight: starSize + bendHeight
    
    property int restQuality: 0
    property int maxStars: 4
    property real starSize: Math.min(width / (maxStars + 1), height / 2)  // Scale based on container size
    property string starColor: "#f1c40f"
    property real spacing: starSize * 0.4  // Spacing proportional to star size
    property real bendHeight: starSize * -0.5  // Bend height proportional to star size

    Row {
        anchors.centerIn: parent
        spacing: root.spacing

        Repeater {
            model: root.maxStars
            
            Text {
                text: index < root.restQuality ? "★" : "☆"
                color: root.starColor
                font.pixelSize: root.starSize
                y: calculateY(index)  // Calculate Y position for curve effect
                
                // Function to calculate Y position for curved effect
                function calculateY(idx) {
                    // Create a parabolic curve that peaks in the middle
                    // x ranges from -1 to 1 across the width
                    let x = (idx / (root.maxStars - 1)) * 2 - 1
                    // y = -ax² + c where 'a' controls curve steepness and 'c' is max height
                    return -root.bendHeight * (x * x) + root.bendHeight
                }

                Behavior on y {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
                
                Behavior on font.pixelSize {
                    NumberAnimation { duration: 200; easing.type: Easing.OutQuad }
                }
            }
        }
    }
} 
