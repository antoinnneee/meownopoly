import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    required property var tileLogic
    
    property real baseHeight: Screen.pixelDensity * 12.5
    
    width: baseHeight * 5.6  // Ratio 5.6:1
    height: baseHeight
    color: "#2a2a2a"
    border.color: "#404040"
    border.width: 1
    radius: baseHeight * 0.12
    
    // Conversion logarithmique
    // Range: 1 à 100 pixels (échelle log)
    property real minValue: 1
    property real maxValue: 100
    
    function toLinear(logValue) {
        // Convertit de 0-100 (slider) vers 1-100 (valeur réelle)
        return Math.round(minValue * Math.pow(maxValue / minValue, logValue / 100))
    }
    
    function toLog(linearValue) {
        // Convertit de 1-100 (valeur réelle) vers 0-100 (slider)
        if (linearValue <= minValue) return 0
        return Math.log(linearValue / minValue) / Math.log(maxValue / minValue) * 100
    }
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: root.baseHeight * 0.12
        spacing: root.baseHeight * 0.16
        
        // Contrôle Width
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.baseHeight * 0.04
            
            // Header avec icône et valeur
            RowLayout {
                Layout.fillWidth: true
                spacing: root.baseHeight * 0.08
                
                Text {
                    text: "↔"
                    color: "#4a9eff"
                    font.pixelSize: root.baseHeight * 0.29
                    font.bold: true
                }
                
                Text {
                    text: "Largeur"
                    color: "#cccccc"
                    font.pixelSize: root.baseHeight * 0.22
                    Layout.fillWidth: true
                }
                
                Rectangle {
                    Layout.preferredWidth: root.baseHeight * 1.04
                    Layout.preferredHeight: root.baseHeight * 0.40
                    color: "#1a1a1a"
                    border.color: "#4a9eff"
                    border.width: 1
                    radius: root.baseHeight * 0.056
                    
                    TextInput {
                        id: widthInput
                        anchors.fill: parent
                        anchors.margins: root.baseHeight * 0.04
                        color: "#ffffff"
                        font.pixelSize: root.baseHeight * 0.20
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: root.tileLogic.currentElementWidth
                        validator: IntValidator { bottom: 1; top: 100 }
                        
                        onEditingFinished: {
                            let value = parseInt(text)
                            if (!isNaN(value) && value >= 1 && value <= 100) {
                                root.tileLogic.currentElementWidth = value
                            } else {
                                text = root.tileLogic.currentElementWidth
                            }
                        }
                    }
                }
            }
            
            // Slider
            Slider {
                id: widthSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                value: root.toLog(root.tileLogic.currentElementWidth)
                stepSize: 0.1
                
                onMoved: {
                    root.tileLogic.currentElementWidth = root.toLinear(value)
                }
                
                background: Rectangle {
                    x: widthSlider.leftPadding
                    y: widthSlider.topPadding + widthSlider.availableHeight / 2 - height / 2
                    width: widthSlider.availableWidth
                    height: root.baseHeight * 0.096
                    radius: root.baseHeight * 0.048
                    color: "#1a1a1a"
                    border.color: "#404040"
                    border.width: 1
                    
                    Rectangle {
                        width: widthSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#4a9eff"
                        radius: root.baseHeight * 0.048
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#4a9eff" }
                            GradientStop { position: 1.0; color: "#2e7fd4" }
                        }
                    }
                }
                
                handle: Rectangle {
                    x: widthSlider.leftPadding + widthSlider.visualPosition * (widthSlider.availableWidth - width)
                    y: widthSlider.topPadding + widthSlider.availableHeight / 2 - height / 2
                    width: root.baseHeight * 0.28
                    height: root.baseHeight * 0.28
                    radius: root.baseHeight * 0.14
                    color: widthSlider.pressed ? "#5aa3ff" : "#ffffff"
                    border.color: "#4a9eff"
                    border.width: root.baseHeight * 0.032
                    
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
            }
        }
        
        // Séparateur
        Rectangle {
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            Layout.topMargin: root.baseHeight * 0.064
            Layout.bottomMargin: root.baseHeight * 0.064
            color: "#404040"
        }
        
        // Contrôle Height
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.baseHeight * 0.04
            
            // Header avec icône et valeur
            RowLayout {
                Layout.fillWidth: true
                spacing: root.baseHeight * 0.08
                
                Text {
                    text: "↕"
                    color: "#ff6b9d"
                    font.pixelSize: root.baseHeight * 0.29
                    font.bold: true
                }
                
                Text {
                    text: "Hauteur"
                    color: "#cccccc"
                    font.pixelSize: root.baseHeight * 0.22
                    Layout.fillWidth: true
                }
                
                Rectangle {
                    Layout.preferredWidth: root.baseHeight * 1.04
                    Layout.preferredHeight: root.baseHeight * 0.40
                    color: "#1a1a1a"
                    border.color: "#ff6b9d"
                    border.width: 1
                    radius: root.baseHeight * 0.056
                    
                    TextInput {
                        id: heightInput
                        anchors.fill: parent
                        anchors.margins: root.baseHeight * 0.04
                        color: "#ffffff"
                        font.pixelSize: root.baseHeight * 0.20
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: root.tileLogic.currentElementHeight
                        validator: IntValidator { bottom: 1; top: 100 }
                        
                        onEditingFinished: {
                            let value = parseInt(text)
                            if (!isNaN(value) && value >= 1 && value <= 100) {
                                root.tileLogic.currentElementHeight = value
                            } else {
                                text = root.tileLogic.currentElementHeight
                            }
                        }
                    }
                }
            }
            
            // Slider
            Slider {
                id: heightSlider
                Layout.fillWidth: true
                from: 0
                to: 100
                value: root.toLog(root.tileLogic.currentElementHeight)
                stepSize: 0.1
                
                onMoved: {
                    root.tileLogic.currentElementHeight = root.toLinear(value)
                }
                
                background: Rectangle {
                    x: heightSlider.leftPadding
                    y: heightSlider.topPadding + heightSlider.availableHeight / 2 - height / 2
                    width: heightSlider.availableWidth
                    height: root.baseHeight * 0.096
                    radius: root.baseHeight * 0.048
                    color: "#1a1a1a"
                    border.color: "#404040"
                    border.width: 1
                    
                    Rectangle {
                        width: heightSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#ff6b9d"
                        radius: root.baseHeight * 0.048
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#ff6b9d" }
                            GradientStop { position: 1.0; color: "#d94d7d" }
                        }
                    }
                }
                
                handle: Rectangle {
                    x: heightSlider.leftPadding + heightSlider.visualPosition * (heightSlider.availableWidth - width)
                    y: heightSlider.topPadding + heightSlider.availableHeight / 2 - height / 2
                    width: root.baseHeight * 0.28
                    height: root.baseHeight * 0.28
                    radius: root.baseHeight * 0.14
                    color: heightSlider.pressed ? "#ff88b3" : "#ffffff"
                    border.color: "#ff6b9d"
                    border.width: root.baseHeight * 0.032
                    
                    Behavior on color {
                        ColorAnimation { duration: 100 }
                    }
                }
            }
        }
    }
}

