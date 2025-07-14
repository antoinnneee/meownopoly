import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import CaseRestArea

Dialog {
    id: testDialog
    title: "CaseRestArea Test Dialog"
    width: 500
    height: 600
    modal: true

    CaseRestArea {
        id: testRestArea
        // name: "Test Rest Area"
        family: CaseRestArea.FT_BROWN
//        position: 1
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: 10

        ColumnLayout {
            width: parent.width
            spacing: 15

            // Basic Properties Section
            GroupBox {
                title: "Basic Properties"
                Layout.fillWidth: true
                
                ColumnLayout {
                    width: parent.width
                    
                    TextField {
                        id: nameField
                        text: testRestArea.name
                        placeholderText: "Enter rest area name"
                        Layout.fillWidth: true
                        onTextChanged: testRestArea.name = text
                    }

                    Label {
                        text: "Current name: " + testRestArea.name
                        font.bold: true
                    }

                    SpinBox {
                        id: positionSpinBox
                        from: 0
                        to: 39
                        value: testRestArea.position
                        onValueChanged: testRestArea.position = value
                    }

                    Label {
                        text: "Current position: " + testRestArea.position
                        font.bold: true
                    }
                }
            }

            // Family Type Section
            GroupBox {
                title: "Family Type"
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width

                    ComboBox {
                        id: familyComboBox
                        model: ["None", "Brown", "Light Blue", "Pink", "Orange", "Red", "Yellow", "Green", "Dark Blue"]
                        currentIndex: testRestArea.family
                        Layout.fillWidth: true
                        onCurrentIndexChanged: {
                            if (currentIndex !== testRestArea.family) {
                                testRestArea.family = currentIndex
                            }
                        }
                    }

                    Label {
                        text: "Current family: " + familyComboBox.currentText
                        font.bold: true
                    }
                }
            }

            // Rest Quality Section
            GroupBox {
                title: "Rest Quality"
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width

                    ComboBox {
                        id: qualityComboBox
                        model: ["None", "1 Star", "2 Stars", "3 Stars", "4 Stars", "Hotel"]
                        currentIndex: testRestArea.restQuality
                        Layout.fillWidth: true
                        onCurrentIndexChanged: {
                            if (currentIndex !== testRestArea.restQuality) {
                                testRestArea.restQuality = currentIndex
                            }
                        }
                    }

                    Label {
                        text: "Current quality: " + qualityComboBox.currentText
                        font.bold: true
                    }

                }
            }

            // Owner Section
            GroupBox {
                title: "Owner Management"
                Layout.fillWidth: true

                ColumnLayout {
                    width: parent.width

                    Label {
                        text: "Owner: " + (testRestArea.owner ? testRestArea.owner.name : "None")
                        font.bold: true
                    }

                    Button {
                        text: "Clear Owner"
                        onClicked: testRestArea.owner = null
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
                            text: "Reset Property"
                            onClicked: {
                                testRestArea.name = "Test Rest Area"
                                testRestArea.position = 1
                                testRestArea.family = 1
                                testRestArea.restQuality = 0
                                testRestArea.owner = null
                            }
                        }

                        Button {
                            text: "Max Upgrade"
                            onClicked: {
                                testRestArea.restQuality = 5 // RQ_HOTEL
                            }
                        }
                    }

                    Button {
                        text: "Simulate Land"
                        onClicked: {
                            if (testPlayer) {
                                testRestArea.onLand(testPlayer)
                            }
                        }
                        enabled: testPlayer !== null
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    standardButtons: Dialog.Close
} 
