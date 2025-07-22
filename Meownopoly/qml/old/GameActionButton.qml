import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: root
    
    // Customizable properties
    property string buttonType: "neutral" // "buy", "decline", "neutral", "custom"
    property color customColor: "#3498db"
    property color customPressedColor: Qt.darker(customColor, 1.2)
    property bool boldText: true
    property int fontSize: 14
    
    // Size properties
    implicitWidth: 120
    implicitHeight: 40
    
    // Background styling
    background: Rectangle {
        color: {
            if (root.pressed) {
                return getPressedColor();
            } else if (!root.enabled) {
                return "#95a5a6"; // Disabled color
            } else {
                return getNormalColor();
            }
        }
        radius: 6
        
        // Optional highlight/glow effect when enabled
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"
            border.width: root.enabled ? 2 : 0
            border.color: Qt.lighter(parent.color, 1.3)
            opacity: 0.5
            visible: root.enabled
        }
    }
    
    // Text styling
    contentItem: Text {
        text: root.text
        color: "white"
        font.pixelSize: root.fontSize
        font.bold: root.boldText
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    
    // Helper functions for colors based on button type
    function getNormalColor() {
        switch (buttonType) {
            case "buy":
                return "#2ecc71"; // Green
            case "decline":
                return "#e74c3c"; // Red
            case "neutral":
                return "#3498db"; // Blue
            case "custom":
                return customColor;
            default:
                return "#34495e"; // Dark blue
        }
    }
    
    function getPressedColor() {
        switch (buttonType) {
            case "buy":
                return "#27ae60"; // Darker green
            case "decline":
                return "#c0392b"; // Darker red
            case "neutral":
                return "#2980b9"; // Darker blue
            case "custom":
                return customPressedColor;
            default:
                return "#2c3e50"; // Darker blue
        }
    }
} 