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
        spacing: 16
        
        // Note explicative
        Text {
            text: "🧭 Configurez la direction de vélocité et les forces de friction/vélocité"
            font.italic: true
            font.pixelSize: 11
            color: "#8a8a8a"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            
            // --- Direction Section ---
            ColumnLayout {
                spacing: 4
                Text {
                    text: "Direction"
                    color: "#5cb85c"
                    font.pixelSize: 11
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                
                ZCP_VectorDirectionPicker {
                    id: velocityPicker
                    circleSize: 100
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
            
            // --- Strength Sliders Section ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                
                // Velocity Strength
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: "Force Vélocité"
                        color: "#5cb85c"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    
                    RowLayout {
                        spacing: 8
                        Slider {
                            id: velocityStrengthSlider
                            Layout.fillWidth: true
                            from: 0.0
                            to: 100.0
                            stepSize: 1.0
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
                            }
                            
                            onMoved: {
                                if (root.targetZoneParameter) {
                                    root.targetZoneParameter.velocityStrenght = value
                                    root.configurationChanged()
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 22
                            color: "#1a1a1a"
                            radius: 4
                            border.color: velocityField.activeFocus ? "#5cb85c" : "#444444"
                            border.width: 1
                            
                            TextInput {
                                id: velocityField
                                anchors.fill: parent
                                text: velocityStrengthSlider.value.toFixed(0)
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                selectByMouse: true
                                
                                onEditingFinished: {
                                    focus = false
                                    var val = parseFloat(text)
                                    if (!isNaN(val)) {
                                        val = Math.max(velocityStrengthSlider.from, Math.min(velocityStrengthSlider.to, val))
                                        velocityStrengthSlider.value = val
                                        velocityField.text = Qt.binding(function() { return velocityStrengthSlider.value.toFixed(0) })
                                        if (root.targetZoneParameter) {
                                            root.targetZoneParameter.velocityStrenght = val
                                            root.configurationChanged()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Friction Strength
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    
                    Text {
                        text: "Force Friction"
                        color: "#e67e22"
                        font.pixelSize: 11
                        font.bold: true
                    }
                    
                    RowLayout {
                        spacing: 8
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
                            }
                            
                            onMoved: {
                                if (root.targetZoneParameter) {
                                    root.targetZoneParameter.frictionStrenght = value
                                    root.configurationChanged()
                                }
                            }
                        }
                        
                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 22
                            color: "#1a1a1a"
                            radius: 4
                            border.color: frictionField.activeFocus ? "#e67e22" : "#444444"
                            border.width: 1
                            
                            TextInput {
                                id: frictionField
                                anchors.fill: parent
                                text: frictionStrengthSlider.value.toFixed(2)
                                color: "#ffffff"
                                font.pixelSize: 11
                                font.bold: true
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                selectByMouse: true

                                onEditingFinished: {
                                    var val = parseFloat(text)
                                    if (!isNaN(val)) {
                                        val = Math.max(frictionStrengthSlider.from, Math.min(frictionStrengthSlider.to, val))
                                        frictionStrengthSlider.value = val
                                        frictionStrengthSlider.text = Qt.binding(function() { return frictionStrengthSlider.value.toFixed(2) })
                                        if (root.targetZoneParameter) {
                                            root.targetZoneParameter.frictionStrenght = val
                                            root.configurationChanged()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Function to update controls from the target
    // We keep it empty or remove it as pure bindings handle everything now
    function updateControls() {
        // Pure property bindings handle synchronization with targetZoneParameter
    }
}
