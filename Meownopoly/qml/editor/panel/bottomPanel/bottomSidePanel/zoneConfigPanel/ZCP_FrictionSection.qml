import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import theme

GroupBox {
    id: root
    title: "Friction"
    
    // Properties
    property var targetZoneParameter: null
    property bool updatingValues: false
    
    // Signal
    signal configurationChanged()
    
    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusS
        border.color: Theme.border
        border.width: 1
    }

    label: Text {
        text: root.title
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeBody
        font.bold: true
        leftPadding: Theme.spacingM
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.spacingM

        // Note explicative
        Text {
            text: "🎯 Force de friction appliquée aux objets dans la zone"
            font.italic: true
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        // Friction Strength
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingL

            Text {
                text: "Friction Strength:"
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeBody
                Layout.preferredWidth: 120
            }
            
            Slider {
                id: frictionSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                stepSize: 0.01
                value: targetZoneParameter ? targetZoneParameter.frictionStrenght : 0.0
                
                background: Rectangle {
                    x: frictionSlider.leftPadding
                    y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                    width: frictionSlider.availableWidth
                    height: 6
                    radius: 3
                    color: Theme.background

                    Rectangle {
                        width: frictionSlider.visualPosition * parent.width
                        height: parent.height
                        radius: 3
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: Theme.accentAlt }
                            GradientStop { position: 1.0; color: Theme.hover(Theme.accentAlt) }
                        }
                    }
                }
                
                handle: Rectangle {
                    x: frictionSlider.leftPadding + frictionSlider.visualPosition * (frictionSlider.availableWidth - width)
                    y: frictionSlider.topPadding + frictionSlider.availableHeight / 2 - height / 2
                    width: 16
                    height: 16
                    radius: 8
                    color: frictionSlider.pressed ? Theme.hover(Theme.accentAlt) : Theme.accentAlt
                    border.color: "#ffffff"
                    border.width: 2

                    Behavior on color {
                        ColorAnimation { duration: Theme.durationFast }
                    }
                }
                
                onMoved: {
                    if (!root.updatingValues && targetZoneParameter) {
                        targetZoneParameter.frictionStrenght = value
                        root.configurationChanged()
                    }
                }
            }
            
            // Value display
            Rectangle {
                Layout.preferredWidth: 50
                Layout.preferredHeight: 24
                color: Theme.background
                radius: Theme.radiusS
                border.color: Theme.border
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: frictionSlider.value.toFixed(2)
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }
        }
    }
    
    // Function to update controls from the target
    function updateControls() {
        if (!targetZoneParameter) return
        
        updatingValues = true
        frictionSlider.value = targetZoneParameter.frictionStrenght
        console.log("friction updated", targetZoneParameter.frictionStrenght)
        updatingValues = false
    }
}
