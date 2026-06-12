import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import theme
import ui_item

GroupBox {
    id: root
    title: "Directions & Forces"
    
    // Properties
    property bool updatingValues: false
    property alias velocityDirectionX: velocityPicker.directionX
    property alias velocityDirectionY: velocityPicker.directionY
    property alias velocityStrength: velocityStrengthSlider.value
    
    // Signal
    signal configurationChanged()
    signal focusReleased()

    // Functions
    function updateFromZoneParameter(zoneParam) {
      if (root.updatingValues) return
        
      console.log("update velocity picker")
      // Update sliders from target values
      velocityPicker.directionX = zoneParam.velocityDirection.x
      velocityPicker.directionY = zoneParam.velocityDirection.y
      velocityStrengthSlider.value = zoneParam.velocityStrenght
    }
    
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
        spacing: Theme.spacingXXL

        // Note explicative
        Text {
            text: qsTr("🧭 Configurez la direction de vélocité et les forces de friction/vélocité")
            font.italic: true
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.textMuted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXXL

            // --- Direction Section ---
            ColumnLayout {
                spacing: Theme.spacingXS
                Text {
                    text: qsTr("Direction")
                    color: Theme.accentAlt
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }

                ZCP_VectorDirectionPicker {
                    id: velocityPicker
                    circleSize: 100
                    arrowColor: Theme.accentAlt
                    highlightColor: Theme.hover(Theme.accentAlt)
                    
                    directionX: 0
                    directionY: 0
                    
                    onDirectionChanged: function(x, y) {
                        root.configurationChanged()
                    }
                }
            }
            
            // --- Strength Sliders Section ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingXL

                // Velocity Strength
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingXS

                    Text {
                        text: qsTr("Force Vélocité")
                        color: Theme.accentAlt
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                    }

                    RowLayout {
                        spacing: Theme.spacingM
                        MeowSlider {
                            id: velocityStrengthSlider
                            Layout.fillWidth: true
                            from: 0.0
                            to: 100.0
                            stepSize: 1.0
                            value: 0.0
                            showValue: false   // champ éditable fourni ci-dessous

                            onMoved: {
                                root.configurationChanged()
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 22
                            color: Theme.background
                            radius: Theme.radiusS
                            border.color: velocityField.activeFocus ? Theme.accentAlt : Theme.border
                            border.width: 1
                            
                            TextInput {
                                id: velocityField
                                anchors.fill: parent
                                text: velocityStrengthSlider.value.toFixed(0)
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeSmall
                                font.bold: true
                                verticalAlignment: TextInput.AlignVCenter
                                horizontalAlignment: TextInput.AlignHCenter
                                selectByMouse: true
                                Keys.onReturnPressed: {
                                    focus = false
                                    root.focusReleased()
                                }
                                
                                onEditingFinished: {
                                    focus = false
                                    var val = parseFloat(text)
                                    if (!isNaN(val)) {
                                        val = Math.max(velocityStrengthSlider.from, Math.min(velocityStrengthSlider.to, val))
                                        velocityStrengthSlider.value = val
                                        velocityField.text = Qt.binding(function() { return velocityStrengthSlider.value.toFixed(0) })
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
