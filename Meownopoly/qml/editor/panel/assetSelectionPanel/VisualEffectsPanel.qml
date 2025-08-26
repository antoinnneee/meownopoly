import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs


Rectangle {
    id: root
    
    // Properties for the target decoration element
    property var targetDecoration: null
    
    // Visual properties
    color: "#2a2a2a"
    radius: 8
    border.color: "#444444"
    border.width: 1
    
    // Dimensions
    implicitHeight: mainLayout.implicitHeight + 20
    
    // Signals
    signal effectChanged()
    
    // Main layout
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Title
        Text {
            text: "Visual Effects"
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
        }
        
        // Color Effects Section
        GroupBox {
            Layout.fillHeight: true
            Layout.fillWidth: true
            title: "Color Effects"
            
            background: Rectangle {
                color: "#333333"
                radius: 4
                border.color: "#555555"
                border.width: 1
            }
            
            label: Text {
                text: parent.title
                color: "#cccccc"
                font.pixelSize: 12
                font.bold: true
                leftPadding: 10
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 5
                
                // Brightness control
                RowLayout {
                    Layout.topMargin: 6
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Brightness:"
                        color: "#cccccc"
                        font.pixelSize: 11
                        Layout.preferredWidth: 80
                    }
                    
                    Slider {
                        id: brightnessSlider
                        Layout.fillWidth: true
                        from: -1.0
                        to: 1.0
                        value: 0.0
                        stepSize: 0.01
                        
                        onValueChanged: {
                            if (targetDecoration) {
                                targetDecoration.effectBrightness = value
                                effectChanged()
                            }
                        }
                        
                        background: Rectangle {
                            color: "#444444"
                            radius: 3
                            implicitHeight: 4
                        }
                        
                        handle: Rectangle {
                            color: "#4CAF50"
                            radius: 6
                            implicitWidth: 12
                            implicitHeight: 12
                        }
                    }
                    
                    Text {
                        text: brightnessSlider.value.toFixed(2)
                        color: "#cccccc"
                        font.pixelSize: 10
                        Layout.preferredWidth: 40
                    }
                    
                    Button {
                        text: "Reset"
                        implicitWidth: 50
                        implicitHeight: 20
                        onClicked: brightnessSlider.value = 0.0
                        
                        background: Rectangle {
                            color: parent.pressed ? "#666666" : "#555555"
                            radius: 3
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#cccccc"
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                
                // Contrast control
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Contrast:"
                        color: "#cccccc"
                        font.pixelSize: 11
                        Layout.preferredWidth: 80
                    }
                    
                    Slider {
                        id: contrastSlider
                        Layout.fillWidth: true
                        from: -1.0
                        to: 2.0
                        value: 0.0
                        stepSize: 0.01
                        
                        onValueChanged: {
                            if (targetDecoration) {
                                targetDecoration.effectContrast = value
                                effectChanged()
                            }
                        }
                        
                        background: Rectangle {
                            color: "#444444"
                            radius: 3
                            implicitHeight: 4
                        }
                        
                        handle: Rectangle {
                            color: "#4CAF50"
                            radius: 6
                            implicitWidth: 12
                            implicitHeight: 12
                        }
                    }
                    
                    Text {
                        text: contrastSlider.value.toFixed(2)
                        color: "#cccccc"
                        font.pixelSize: 10
                        Layout.preferredWidth: 40
                    }
                    
                    Button {
                        text: "Reset"
                        implicitWidth: 50
                        implicitHeight: 20
                        onClicked: contrastSlider.value = 0.0
                        
                        background: Rectangle {
                            color: parent.pressed ? "#666666" : "#555555"
                            radius: 3
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#cccccc"
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                
                // Saturation control
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Saturation:"
                        color: "#cccccc"
                        font.pixelSize: 11
                        Layout.preferredWidth: 80
                    }
                    
                    Slider {
                        id: saturationSlider
                        Layout.fillWidth: true
                        from: -1.0
                        to: 2.0
                        value: 0.0
                        stepSize: 0.01
                        
                        onValueChanged: {
                            if (targetDecoration) {
                                targetDecoration.effectSaturation = value
                                effectChanged()
                            }
                        }
                        
                        background: Rectangle {
                            color: "#444444"
                            radius: 3
                            implicitHeight: 4
                        }
                        
                        handle: Rectangle {
                            color: "#4CAF50"
                            radius: 6
                            implicitWidth: 12
                            implicitHeight: 12
                        }
                    }
                    
                    Text {
                        text: saturationSlider.value.toFixed(2)
                        color: "#cccccc"
                        font.pixelSize: 10
                        Layout.preferredWidth: 40
                    }
                    
                    Button {
                        text: "Reset"
                        implicitWidth: 50
                        implicitHeight: 20
                        onClicked: saturationSlider.value = 0.0
                        
                        background: Rectangle {
                            color: parent.pressed ? "#666666" : "#555555"
                            radius: 3
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#cccccc"
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                
                // Colorization control
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Colorization:"
                        color: "#cccccc"
                        font.pixelSize: 11
                        Layout.preferredWidth: 80
                    }
                    
                    Slider {
                        id: colorizationSlider
                        Layout.fillWidth: true
                        from: 0.0
                        to: 1.0
                        value: 0.0
                        stepSize: 0.01
                        
                        onValueChanged: {
                            if (targetDecoration) {
                                targetDecoration.effectColorization = value
                                effectChanged()
                            }
                        }
                        
                        background: Rectangle {
                            color: "#444444"
                            radius: 3
                            implicitHeight: 4
                        }
                        
                        handle: Rectangle {
                            color: "#4CAF50"
                            radius: 6
                            implicitWidth: 12
                            implicitHeight: 12
                        }
                    }
                    
                    Text {
                        text: colorizationSlider.value.toFixed(2)
                        color: "#cccccc"
                        font.pixelSize: 10
                        Layout.preferredWidth: 40
                    }
                    
                    Button {
                        text: "Reset"
                        implicitWidth: 50
                        implicitHeight: 20
                        onClicked: colorizationSlider.value = 0.0
                        
                        background: Rectangle {
                            color: parent.pressed ? "#666666" : "#555555"
                            radius: 3
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#cccccc"
                            font.pixelSize: 9
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
                
                // Colorization color picker
                RowLayout {
                    Layout.fillWidth: true
                    
                    Text {
                        text: "Color:"
                        color: "#cccccc"
                        font.pixelSize: 11
                        Layout.preferredWidth: 80
                    }
                    
                    Rectangle {
                        id: colorPreview
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 20
                        color: targetDecoration ? targetDecoration.effectColorizationColor : "#ffffff"
                        border.color: "#666666"
                        border.width: 1
                        radius: 3
                        property color customModelColor: "#ffffff"
                        ColorDialog {
                            id: colorDialog
                            selectedColor: colorPreview.customModelColor
                            onAccepted: colorPreview.customModelColor = selectedColor
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: colorDialog.open()
                        }
                    }
                    
                    // Color presets
                    Row {
                        spacing: 3
                        
                        Repeater {
                            model: ["#ff0000", "#00ff00", "#0000ff", "#ffff00", "#ff00ff", "#00ffff", colorPreview.customModelColor]
                            
                            Rectangle {
                                width: 15
                                height: 15
                                color: modelData
                                border.color: "#666666"
                                border.width: 1
                                radius: 2
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        if (targetDecoration) {
                                            targetDecoration.effectColorizationColor = modelData
                                            effectChanged()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    Item { Layout.fillWidth: true }
                }
            }
        }
        
        // Advanced Effects Section
        GroupBox {
            Layout.fillHeight: true
            Layout.fillWidth: true
            title: "Advanced Effects"
            
            background: Rectangle {
                color: "#333333"
                radius: 4
                border.color: "#555555"
                border.width: 1
            }
            
            label: Text {
                text: parent.title
                color: "#cccccc"
                font.pixelSize: 12
                font.bold: true
                leftPadding: 10
            }
            
            ColumnLayout {
                anchors.fill: parent
                spacing: 10
                
                // Blur effect
                RowLayout {
                    Layout.fillWidth: true
                    
                    CheckBox {
                        id: blurEnabledCheck
                        text: "Blur"
                        
                        onCheckedChanged: {
                            if (targetDecoration) {
                                targetDecoration.effectBlurEnabled = checked
                                effectChanged()
                            }
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 16
                            implicitHeight: 16
                            color: parent.checked ? "#4CAF50" : "#444444"
                            border.color: "#666666"
                            radius: 2
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "white"
                                visible: parent.parent.checked
                                font.pixelSize: 10
                            }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#cccccc"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    Slider {
                        id: blurSlider
                        Layout.fillWidth: true
                        from: 0.0
                        to: 1.0
                        value: 0.0
                        stepSize: 0.01
                        enabled: blurEnabledCheck.checked
                        
                        onValueChanged: {
                            if (targetDecoration) {
                                targetDecoration.effectBlur = value
                                effectChanged()
                            }
                        }
                        
                        background: Rectangle {
                            color: parent.enabled ? "#444444" : "#333333"
                            radius: 3
                            implicitHeight: 4
                        }
                        
                        handle: Rectangle {
                            color: parent.enabled ? "#4CAF50" : "#666666"
                            radius: 6
                            implicitWidth: 12
                            implicitHeight: 12
                        }
                    }
                    
                    Text {
                        text: blurSlider.value.toFixed(2)
                        color: blurEnabledCheck.checked ? "#cccccc" : "#666666"
                        font.pixelSize: 10
                        Layout.preferredWidth: 40
                    }
                }
                
                // Shadow effect
                RowLayout {
                    Layout.fillWidth: true
                    
                    CheckBox {
                        id: shadowEnabledCheck
                        text: "Shadow"
                        
                        onCheckedChanged: {
                            if (targetDecoration) {
                                targetDecoration.effectShadowEnabled = checked
                                effectChanged()
                            }
                        }
                        
                        indicator: Rectangle {
                            implicitWidth: 16
                            implicitHeight: 16
                            color: parent.checked ? "#4CAF50" : "#444444"
                            border.color: "#666666"
                            radius: 2
                            
                            Text {
                                anchors.centerIn: parent
                                text: "✓"
                                color: "white"
                                visible: parent.parent.checked
                                font.pixelSize: 10
                            }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: "#cccccc"
                            leftPadding: parent.indicator.width + 5
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    Slider {
                        id: shadowBlurSlider
                        Layout.fillWidth: true
                        from: 0.0
                        to: 1.0
                        value: 1.0
                        stepSize: 0.01
                        enabled: shadowEnabledCheck.checked
                        
                        onValueChanged: {
                            if (targetDecoration) {
                                targetDecoration.effectShadowBlur = value
                                effectChanged()
                            }
                        }
                        
                        background: Rectangle {
                            color: parent.enabled ? "#444444" : "#333333"
                            radius: 3
                            implicitHeight: 4
                        }
                        
                        handle: Rectangle {
                            color: parent.enabled ? "#4CAF50" : "#666666"
                            radius: 6
                            implicitWidth: 12
                            implicitHeight: 12
                        }
                    }
                    
                    Text {
                        text: shadowBlurSlider.value.toFixed(2)
                        color: shadowEnabledCheck.checked ? "#cccccc" : "#666666"
                        font.pixelSize: 10
                        Layout.preferredWidth: 40
                    }
                }
            }
        }
        
        // Reset all button
        RowLayout {
            Layout.fillWidth: true
            
            Button {
                text: "Reset Color Effects"
                Layout.fillWidth: true
                
                onClicked: {
                    if (targetDecoration) {
                        targetDecoration.resetColorEffects()
                        updateFromTarget()
                        effectChanged()
                    }
                }
                
                background: Rectangle {
                    color: parent.pressed ? "#666666" : "#555555"
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#cccccc"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Button {
                text: "Reset All Effects"
                Layout.fillWidth: true
                
                onClicked: {
                    if (targetDecoration) {
                        targetDecoration.resetAllEffects()
                        updateFromTarget()
                        effectChanged()
                    }
                }
                
                background: Rectangle {
                    color: parent.pressed ? "#ff6666" : "#ff4444"
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "#ffffff"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        
        // Performance indicator
    }
    
    // Functions
    function updateFromTarget() {
        if (!targetDecoration) return
        
        // Update sliders from target values
        brightnessSlider.value = targetDecoration.effectBrightness
        contrastSlider.value = targetDecoration.effectContrast
        saturationSlider.value = targetDecoration.effectSaturation
        colorizationSlider.value = targetDecoration.effectColorization
        
        // Update checkboxes
        blurEnabledCheck.checked = targetDecoration.effectBlurEnabled
        shadowEnabledCheck.checked = targetDecoration.effectShadowEnabled
        
        // Update blur/shadow sliders
        blurSlider.value = targetDecoration.effectBlur
        shadowBlurSlider.value = targetDecoration.effectShadowBlur
    }
    
    onTargetDecorationChanged: {
        updateFromTarget()
    }
}
