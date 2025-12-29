import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

GroupBox {
    id: root
    title: "Directions & Forces"
    
    // Properties
    property var targetZoneParameter: null
    property bool updatingValues: false
    
    // Signal
    signal configurationChanged()
    
    background: Rectangle {
        color: "#2a2a2a"
        radius: 4
        border.color: "#444444"
        border.width: 1
    }
    
    label: Text {
        text: root.title
        color: "#cccccc"
        font.pixelSize: 12
        font.bold: true
        leftPadding: 8
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        
        // Note explicative
        Text {
            text: "🧭 Configurez les directions et forces de la zone"
            font.italic: true
            font.pixelSize: 11
            color: "#8a8a8a"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        // Row avec les deux pickers
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            
            // Velocity Direction
            ColumnLayout {
                spacing: 4
                
                Text {
                    text: "Vélocité"
                    color: "#5cb85c"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                ZCP_VectorDirectionPicker {
                    id: velocityPicker
                    circleSize: 80
                    arrowColor: "#5cb85c"
                    highlightColor: "#7bd97f"
                    
                    directionX: root.targetZoneParameter ? root.targetZoneParameter.velocityDirection.x : 0
                    directionY: root.targetZoneParameter ? root.targetZoneParameter.velocityDirection.y : 0
                    
                    onDirectionChanged: function(x, y) {
                        if (!root.updatingValues && root.targetZoneParameter) {
                            root.targetZoneParameter.velocityDirection = Qt.vector2d(x, y)
                            root.configurationChanged()
                        }
                    }
                }
            }
            
            // Friction Direction
            ColumnLayout {
                spacing: 4
                
                Text {
                    text: "Friction"
                    color: "#e67e22"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                ZCP_VectorDirectionPicker {
                    id: frictionPicker
                    circleSize: 80
                    arrowColor: "#e67e22"
                    highlightColor: "#f39c12"
                    
                    directionX: root.targetZoneParameter ? root.targetZoneParameter.frictionDirection.x : 0
                    directionY: root.targetZoneParameter ? root.targetZoneParameter.frictionDirection.y : 0
                    
                    onDirectionChanged: function(x, y) {
                        if (!root.updatingValues && root.targetZoneParameter) {
                            root.targetZoneParameter.frictionDirection = Qt.vector2d(x, y)
                            root.configurationChanged()
                        }
                    }
                }
            }
        }
        
        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }
        
        // Velocity Strength Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Text {
                text: "Force Vélocité:"
                color: "#5cb85c"
                font.pixelSize: 12
                Layout.preferredWidth: 100
            }
            
            Slider {
                id: velocityStrengthSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: root.targetZoneParameter ? root.targetZoneParameter.velocityStrenght : 0.0
                
                background: Rectangle {
                    x: velocityStrengthSlider.leftPadding
                    y: velocityStrengthSlider.topPadding + velocityStrengthSlider.availableHeight / 2 - height / 2
                    width: velocityStrengthSlider.availableWidth
                    height: 6
                    radius: 3
                    color: "#1a1a1a"
                    
                    Rectangle {
                        width: velocityStrengthSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#4a9c4e" }
                            GradientStop { position: 1.0; color: "#6bc96f" }
                        }
                    }
                }
                
                handle: Rectangle {
                    x: velocityStrengthSlider.leftPadding + velocityStrengthSlider.visualPosition * (velocityStrengthSlider.availableWidth - width)
                    y: velocityStrengthSlider.topPadding + velocityStrengthSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: velocityStrengthSlider.pressed ? "#7bd97f" : "#5cb85c"
                    border.color: "#ffffff"
                    border.width: 2
                    
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
                
                onMoved: {
                    if (!root.updatingValues && root.targetZoneParameter) {
                        root.targetZoneParameter.velocityStrenght = value
                        root.configurationChanged()
                    }
                }
            }
            
            // Value display
            Rectangle {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 24
                color: "#1a1a1a"
                radius: 4
                border.color: "#444444"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: velocityStrengthSlider.value.toFixed(2)
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }

        // Friction Strength Slider
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            
            Text {
                text: "Force Friction:"
                color: "#e67e22"
                font.pixelSize: 12
                Layout.preferredWidth: 100
            }
            
            Slider {
                id: frictionStrengthSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: root.targetZoneParameter ? root.targetZoneParameter.frictionStrenght : 0.0
                
                background: Rectangle {
                    x: frictionStrengthSlider.leftPadding
                    y: frictionStrengthSlider.topPadding + frictionStrengthSlider.availableHeight / 2 - height / 2
                    width: frictionStrengthSlider.availableWidth
                    height: 6
                    radius: 3
                    color: "#1a1a1a"
                    
                    Rectangle {
                        width: frictionStrengthSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "#d35400" }
                            GradientStop { position: 1.0; color: "#e67e22" }
                        }
                    }
                }
                
                handle: Rectangle {
                    x: frictionStrengthSlider.leftPadding + frictionStrengthSlider.visualPosition * (frictionStrengthSlider.availableWidth - width)
                    y: frictionStrengthSlider.topPadding + frictionStrengthSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: frictionStrengthSlider.pressed ? "#f39c12" : "#e67e22"
                    border.color: "#ffffff"
                    border.width: 2
                    
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
                
                onMoved: {
                    if (!root.updatingValues && root.targetZoneParameter) {
                        root.targetZoneParameter.frictionStrenght = value
                        root.configurationChanged()
                    }
                }
            }
            
            // Value display
            Rectangle {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 24
                color: "#1a1a1a"
                radius: 4
                border.color: "#444444"
                border.width: 1
                
                Text {
                    anchors.centerIn: parent
                    text: frictionStrengthSlider.value.toFixed(2)
                    color: "#ffffff"
                    font.pixelSize: 11
                    font.bold: true
                }
            }
        }
    }
    
    // Function to update controls from the target
    function updateControls() {
        if (!root.targetZoneParameter) return
        
        updatingValues = true
        velocityPicker.setDirection(
            root.targetZoneParameter.velocityDirection.x,
            root.targetZoneParameter.velocityDirection.y
        )
        frictionPicker.setDirection(
            root.targetZoneParameter.frictionDirection.x,
            root.targetZoneParameter.frictionDirection.y
        )
        velocityStrengthSlider.value = root.targetZoneParameter.velocityStrenght
        frictionStrengthSlider.value = root.targetZoneParameter.frictionStrenght
        updatingValues = false
    }
}
