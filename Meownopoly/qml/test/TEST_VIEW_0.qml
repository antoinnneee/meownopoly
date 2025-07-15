import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import Player

Dialog {
    id: testDialog
    title: "Player Test Dialog"
    width: 500
    height: 600
    modal: true

    Player {
        id: testPlayer
        name: "Test Player"
        color: "#FF6B6B"
        kibble: 1500
        position: 0
        inJail: false
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 10

        ColumnLayout {
            width: parent.width
            spacing: 15

            // Player Name Section
            GroupBox {
                title: "Player Name"
                Layout.fillWidth: true
                
                ColumnLayout {
                    width: parent.width
                    
                    TextField {
                        id: nameField
                        text: testPlayer.name
                        placeholderText: "Enter player name"
                        Layout.fillWidth: true
                        onTextChanged: testPlayer.name = text
                    }
                    
                    Label {
                        text: "Current name: " + testPlayer.name
                        font.bold: true
                    }
                }
            }

            // Player Color Section
            GroupBox {
                title: "Player Color"
                Layout.fillWidth: true
                
                ColumnLayout {
                    width: parent.width
                    
                    Row {
                        spacing: 10
                        
                        Rectangle {
                            width: 50
                            height: 30
                            color: testPlayer.color
                            border.color: "black"
                            border.width: 1
                        }
                        
                        Button {
                            text: "Red"
                            onClicked: testPlayer.color = "#FF6B6B"
                        }
                        
                        Button {
                            text: "Blue"
                            onClicked: testPlayer.color = "#4ECDC4"
                        }
                        
                        Button {
                            text: "Green"
                            onClicked: testPlayer.color = "#45B7D1"
                        }
                        
                        Button {
                            text: "Yellow"
                            onClicked: testPlayer.color = "#FFA07A"
                        }
                    }
                    
                    Label {
                        text: "Current color: " + testPlayer.color
                        font.bold: true
                    }
                }
            }

            // Kibble Section
            GroupBox {
                title: "Kibble (Money)"
                Layout.fillWidth: true
                
                ColumnLayout {
                    width: parent.width
                    
                    Row {
                        spacing: 10
                        
                        SpinBox {
                            id: kibbleSpinBox
                            from: 0
                            to: 99999
                            value: testPlayer.kibble
                            onValueChanged: testPlayer.kibble = value
                        }
                        
                        Button {
                            text: "Add 100"
                            onClicked: testPlayer.earnKibble(100)
                        }
                        
                        Button {
                            text: "Spend 50"
                            onClicked: testPlayer.spendKibble(50)
                        }
                    }
                    
                    Label {
                        text: "Current kibble: " + testPlayer.kibble
                        font.bold: true
                    }
                }
            }

            // Position Section
            GroupBox {
                title: "Position"
                Layout.fillWidth: true
                
                ColumnLayout {
                    width: parent.width
                    
                    Row {
                        spacing: 10
                        
                        SpinBox {
                            id: positionSpinBox
                            from: 0
                            to: 39
                            value: testPlayer.position
                            onValueChanged: testPlayer.position = value
                        }
                        
                        Button {
                            text: "Move +1"
                            onClicked: testPlayer.position = testPlayer.position + 1
                        }
                        
                        Button {
                            text: "Go to Start"
                            onClicked: testPlayer.position = 0
                        }
                    }
                    
                    Label {
                        text: "Current position: " + testPlayer.position
                        font.bold: true
                    }
                }
            }

            // Jail Section
            GroupBox {
                title: "Jail Status"
                Layout.fillWidth: true
                
                ColumnLayout {
                    width: parent.width
                    
                    Row {
                        spacing: 10
                        
                        CheckBox {
                            id: jailCheckBox
                            text: "In Jail"
                            checked: testPlayer.inJail
                            onClicked: {
                                testPlayer.inJail = checked
                            }
                        }
                        
                        Button {
                            text: "Send to Jail"
                            onClicked: testPlayer.inJail = true
                        }
                        
                        Button {
                            text: "Release"
                            onClicked: testPlayer.inJail = false
                        }
                    }
                    
                    Label {
                        text: "In jail: " + (testPlayer.inJail ? "Yes" : "No")
                        font.bold: true
                        color: testPlayer.inJail ? "red" : "green"
                    }
                }
            }

            // Properties Count Section
            GroupBox {
                title: "Properties & Assets"
                Layout.fillWidth: true
                
                ColumnLayout {
                    width: parent.width
                    
                    Label {
                        text: "Property Count: " + testPlayer.propertyCount
                        font.bold: true
                    }
                    
                    Label {
                        text: "Cat Device Count: " + testPlayer.catDeviceCount
                        font.bold: true
                    }
                    
                    Label {
                        text: "Cat Door Count: " + testPlayer.catDoorCount
                        font.bold: true
                    }
                }
            }

            // Test Actions Section
            GroupBox {
                title: "Test Actions"
                Layout.fillWidth: true
                
                ColumnLayout {
                    width: parent.width
                    
                    Row {
                        spacing: 10
                        
                        Button {
                            text: "Reset Player"
                            onClicked: {
                                testPlayer.name = "Test Player"
                                testPlayer.color = "#FF6B6B"
                                testPlayer.kibble = 1500
                                testPlayer.position = 0
                                testPlayer.inJail = false
                            }
                        }
                        
                        Button {
                            text: "Rich Player"
                            onClicked: {
                                testPlayer.kibble = 10000
                                testPlayer.name = "Rich Cat"
                            }
                        }
                        
                        Button {
                            text: "Poor Player"
                            onClicked: {
                                testPlayer.kibble = 10
                                testPlayer.name = "Poor Cat"
                            }
                        }
                    }
                }
            }
        }
    }

    standardButtons: Dialog.Close
}
