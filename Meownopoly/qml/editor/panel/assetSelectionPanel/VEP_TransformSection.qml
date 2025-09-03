import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    
    // Properties for the target decoration element
    property var targetDecoration: null
    property alias rotationSlider: rotationSlider
    property alias horizontalMirrorCheck: horizontalMirrorCheck
    property alias verticalMirrorCheck: verticalMirrorCheck
    // Visual properties
    color: "transparent"
    radius: 4
    border.color: "#555555"
    border.width: 1
    
    // Dimensions
    height: mainLayout.implicitHeight + 8
    width: mainLayout.implicitWidth
    
    // Signals
    signal effectChanged()
    
    // Main layout
    Column {
        id: mainLayout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8
        spacing: 8
        
        // Title
        Text {
            id: title
            text: "Transform"
            color: "#ffffff"
            font.pixelSize: 14
            font.bold: true
            anchors.left: parent.left
            anchors.right: parent.right
        }
        
        // Rotation Section
        Rectangle {
            id: rotationSection
            anchors.left: parent.left
            anchors.right: parent.right
            height: rotationLayout.implicitHeight + 8
            color: "#333333"
            radius: 4
            
            Column {
                id: rotationLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 6
                
                Text {
                    text: "Rotation"
                    color: "#cccccc"
                    font.pixelSize: 12
                    font.bold: true
                }
                
                Row {
                    spacing: 8
                    anchors.left: parent.left
                    anchors.right: parent.right
                    
                    Text {
                        text: "Angle:"
                        color: "#cccccc"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    
                    Slider {
                        id: rotationSlider
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 80
                        from: 0
                        to: 360
                        value: 0
                        stepSize: 1
                        
                        onValueChanged: {
                            if (targetDecoration) {
                                targetDecoration.displaySettings.rotationAngle = value
                                root.effectChanged()
                            }
                        }
                    }
                    
                    Text {
                        text: Math.round(rotationSlider.value) + "°"
                        color: "#cccccc"
                        font.pixelSize: 11
                        anchors.verticalCenter: parent.verticalCenter
                        width: 30
                        horizontalAlignment: Text.AlignRight
                    }
                }
            }
        }
        
        // Mirror Section
        Rectangle {
            id: mirrorSection
            anchors.left: parent.left
            anchors.right: parent.right
            height: mirrorLayout.implicitHeight + 8
            color: "#333333"
            radius: 4
            
            Column {
                id: mirrorLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6
                spacing: 6
                
                Text {
                    text: "Mirror"
                    color: "#cccccc"
                    font.pixelSize: 12
                    font.bold: true
                }
                
                Row {
                    spacing: 16
                    anchors.left: parent.left
                    anchors.right: parent.right
                    
                    CheckBox {
                        id: horizontalMirrorCheck
                        text: "Horizontal"
                        checked: false
                        font.pixelSize: 11
                        
                        onCheckedChanged: {
                            if (targetDecoration) {
                                targetDecoration.displaySettings.mirrorHorizontal = checked
                                root.effectChanged()
                            }
                        }
                    }
                    
                    CheckBox {
                        id: verticalMirrorCheck
                        text: "Vertical"
                        checked: false
                        font.pixelSize: 11
                        
                        onCheckedChanged: {
                            if (targetDecoration) {
                                targetDecoration.displaySettings.mirrorVertical = checked
                                root.effectChanged()
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Functions
    function updateFromTarget() {
        if (!targetDecoration) return
        
        // Update rotation slider
        rotationSlider.value = targetDecoration.displaySettings.rotationAngle
        
        // Update mirror checkboxes
        horizontalMirrorCheck.checked = targetDecoration.displaySettings.mirrorHorizontal
        verticalMirrorCheck.checked = targetDecoration.displaySettings.mirrorVertical
    }
    
    onTargetDecorationChanged: {
        updateFromTarget()
    }
}
