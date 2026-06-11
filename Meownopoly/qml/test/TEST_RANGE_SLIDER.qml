import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme

Rectangle {
    id: window
    color: Theme.surface
    
    signal backRequested()
    
    // Back button
    Button {
        id: backButton
        text: "← Back"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Theme.spacingL
        z: 100
        
        onClicked: window.backRequested()
    }
    
    Text {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacingXXL
        text: "Range Slider Test"
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeHeading
        font.bold: true
    }

    Column {
        anchors.centerIn: parent
        spacing: 30
        width: 400
        
        // Test properties
        property int minPlan: 1
        property int maxPlan: 10
        
        Text {
            text: "Plan Range Control Test"
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeTitle
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        
        Rectangle {
            width: parent.width
            height: 200
            color: Theme.surfaceHover
            border.color: Theme.borderLight
            border.width: 2
            radius: Theme.radiusL
            
            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingHuge
                spacing: Theme.spacingXXL
                
                Text {
                    text: "Plans: " + Math.round(planRangeSlider.first.value) + " - " + Math.round(planRangeSlider.second.value)
                    color: Theme.textPrimary
                    font.bold: true
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                RangeSlider {
                    id: planRangeSlider
                    from: 1
                    to: 10
                    stepSize: 1
                    width: parent.width
                    
                    first.value: parent.parent.minPlan
                    second.value: parent.parent.maxPlan
                    
                    first.onValueChanged: {
                        parent.parent.minPlan = Math.round(first.value)
                    }
                    
                    second.onValueChanged: {
                        parent.parent.maxPlan = Math.round(second.value)
                    }
                    
                    // Custom styling for better visibility
                    background: Rectangle {
                        x: planRangeSlider.leftPadding
                        y: planRangeSlider.topPadding + planRangeSlider.availableHeight / 2 - height / 2
                        width: planRangeSlider.availableWidth
                        height: 4
                        radius: 2
                        color: "#bdbebf"
                        
                        Rectangle {
                            x: planRangeSlider.first.visualPosition * parent.width
                            width: planRangeSlider.second.visualPosition * parent.width - x
                            height: parent.height
                            color: "#3498db"
                            radius: 2
                        }
                    }
                    
                    first.handle: Rectangle {
                        x: planRangeSlider.leftPadding + planRangeSlider.first.visualPosition * (planRangeSlider.availableWidth - width)
                        y: planRangeSlider.topPadding + planRangeSlider.availableHeight / 2 - height / 2
                        width: 24
                        height: 24
                        radius: 12
                        color: planRangeSlider.first.pressed ? "#2980b9" : "#3498db"
                        border.color: "#2c3e50"
                        border.width: 2
                        
                        Text {
                            anchors.centerIn: parent
                            text: Math.round(planRangeSlider.first.value)
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeCaption
                            font.bold: true
                        }
                    }
                    
                    second.handle: Rectangle {
                        x: planRangeSlider.leftPadding + planRangeSlider.second.visualPosition * (planRangeSlider.availableWidth - width)
                        y: planRangeSlider.topPadding + planRangeSlider.availableHeight / 2 - height / 2
                        width: 24
                        height: 24
                        radius: 12
                        color: planRangeSlider.second.pressed ? "#27ae60" : "#2ecc71"
                        border.color: "#2c3e50"
                        border.width: 2
                        
                        Text {
                            anchors.centerIn: parent
                            text: Math.round(planRangeSlider.second.value)
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeCaption
                            font.bold: true
                        }
                    }
                }
                
                Text {
                    text: "Min ← → Max"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                    font.italic: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                // Quick preset buttons
                Row {
                    spacing: Theme.spacingL
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    Button {
                        text: "Tout (1-10)"
                        font.pixelSize: Theme.fontSizeCaption
                        onClicked: {
                            parent.parent.parent.minPlan = 1
                            parent.parent.parent.maxPlan = 10
                        }
                        background: Rectangle {
                            color: parent.pressed ? "#95a5a6" : "#bdc3c7"
                            radius: Theme.radiusS
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#2c3e50"
                            font.pixelSize: Theme.fontSizeCaption
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    Button {
                        text: "Seul plan"
                        font.pixelSize: Theme.fontSizeCaption
                        onClicked: {
                            var currentMax = parent.parent.parent.maxPlan
                            parent.parent.parent.minPlan = currentMax
                            parent.parent.parent.maxPlan = currentMax
                        }
                        background: Rectangle {
                            color: parent.pressed ? "#95a5a6" : "#bdc3c7"
                            radius: Theme.radiusS
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#2c3e50"
                            font.pixelSize: Theme.fontSizeCaption
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    
                    Button {
                        text: "3 derniers"
                        font.pixelSize: Theme.fontSizeCaption
                        onClicked: {
                            var currentMax = parent.parent.parent.maxPlan
                            parent.parent.parent.minPlan = Math.max(1, currentMax - 2)
                            parent.parent.parent.maxPlan = currentMax
                        }
                        background: Rectangle {
                            color: parent.pressed ? "#95a5a6" : "#bdc3c7"
                            radius: Theme.radiusS
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#2c3e50"
                            font.pixelSize: Theme.fontSizeCaption
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }
        
        // Simulation des éléments par plan
        Rectangle {
            width: parent.width
            height: 250
            color: Theme.surfaceHover
            border.color: Theme.borderLight
            border.width: 2
            radius: Theme.radiusL
            
            Column {
                anchors.fill: parent
                anchors.margins: Theme.spacingXXL
                spacing: Theme.spacingXS
                
                Text {
                    text: "Simulation d'éléments par plan"
                    color: Theme.textPrimary
                    font.bold: true
                    font.pixelSize: Theme.fontSizeMedium
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                ScrollView {
                    width: parent.width
                    height: parent.height - 30
                    
                    Column {
                        spacing: Theme.spacingXXS
                        
                        Repeater {
                            model: 10
                            
                            Rectangle {
                                width: 350
                                height: 20
                                color: {
                                    var planNum = index + 1
                                    if (planNum >= parent.parent.parent.parent.minPlan && 
                                        planNum <= parent.parent.parent.parent.maxPlan) {
                                        return "#4CAF50" // Visible
                                    } else {
                                        return "#757575" // Masqué
                                    }
                                }
                                radius: Theme.radiusXS
                                
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: Theme.spacingL
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Plan " + (index + 1) + " - Éléments de ce niveau"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.bold: parent.color === "#4CAF50"
                                }
                                
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: Theme.spacingL
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: parent.color === "#4CAF50" ? "VISIBLE" : "MASQUÉ"
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeTiny
                                    font.bold: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
