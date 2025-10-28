import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import CaseRestArea
import CaseCatPerks
import Case
import "../case"
import Player

Rectangle {
//    title: "Test Case"
    width: 600
    height: 400

    property Case caseInfo: null
    Player{
        id: player
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        Rectangle { // left side
            id: leftSide
            Layout.preferredWidth: parent.width * 0.3
            Layout.preferredHeight: parent.height * 0.4
            Layout.alignment: Qt.AlignVCenter
            border.color: "black"
            border.width: 1
            color: "white"

            CaseTile {
                anchors.fill: parent
                caseData: caseInfo
            }
        }

        // Right side controls
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Label {
                text: "Case Name:"
                font.bold: true
            }

            TextField {
                id: nameField
                Layout.fillWidth: true
                text: caseInfo ? caseInfo.name : ""
                placeholderText: "Enter case name"
                onEditingFinished: {
                    if (caseInfo) {
                        caseInfo.name = text
                    }
                }
            }

            Label {
                text: "Case Type:"
                font.bold: true
            }

            ComboBox {
                id: typeComboBox
                Layout.fillWidth: true
                
                // Modèle avec les types de cases et leurs noms lisibles
                model: [
                    { value: Case.CS_KibbleDispenser, text: "Kibble Dispenser (Départ)" },
                    { value: Case.CS_RestArea, text: "Rest Area (Terrain)" },
                    { value: Case.CS_CardBoardBox, text: "Cardboard Box (Caisse communauté)" },
                    { value: Case.CS_CatNip, text: "Cat Nip (Chance)" },
                    { value: Case.CS_Jail, text: "Jail (Prison)" },
                    { value: Case.CS_ToJail, text: "To Jail (Aller en prison)" },
                    { value: Case.CS_CatDoor, text: "Cat Door (Gare)" },
                    { value: Case.CS_FreeNap, text: "Free Nap (Parking gratuit)" },
                    { value: Case.CS_Device, text: "Device (Service électricité)" },
                    { value: Case.CS_Taxe, text: "Taxe (Taxe de luxe)" },
                    { value: Case.CS_Unknow, text: "Unknown (Inconnu)" }
                ]
                
                textRole: "text"
                valueRole: "value"
                
                // Initialisation avec le type actuel
                Component.onCompleted: {
                }

                
                // Mise à jour de la case quand la sélection change
                onCurrentValueChanged: {
                    if (currentValue !== undefined) {
                        aseInfo = Game.getNewCaseType(currentValue);
                        if (caseInfo.type == Case.CS_RestArea)
                        {
                            caseInfo.setOwner(player);
                            caseInfo.family = CaseRestArea.FT_BROWN
                            caseInfo.restQuality = 3
                        }
                    }
                }
                
                // Fonction helper pour trouver l'index par valeur
                function findIndexByValue(value) {
                    for (let i = 0; i < model.length; i++) {
                        if (model[i].value === value) {
                            return i
                        }
                    }
                    return 0 // Retourne le premier par défaut
                }
            }

            // Affichage des informations sur la case
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                border.color: "#cccccc"
                border.width: 1
                color: "#f8f8f8"
                radius: 5
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5
                    
                    Label {
                        text: "Case Information:"
                        font.bold: true
                        font.pixelSize: 14
                    }
                    
                    Label {
                        text: "Name: " + caseInfo.name
                        font.pixelSize: 12
                    }
                    
                    Label {
                        text: "Type: " + caseInfo.type + " (" + typeComboBox.currentText + ")"
                        font.pixelSize: 12
                    }
                    
                    Label {
                        text: "Position: " + caseInfo.position
                        font.pixelSize: 12
                    }
                }
            }

            Item { // Spacer
                Layout.fillHeight: true
            }
        }
        
        // Player customization section
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Label {
                text: "Player Customization:"
                font.bold: true
                font.pixelSize: 16
            }

            // Player Name
            Label {
                text: "Player Name:"
                font.bold: true
            }

            TextField {
                id: playerNameField
                Layout.fillWidth: true
                text: player.name
                placeholderText: "Enter player name"
                onEditingFinished: {
                    player.name = text
                }
            }

            // Player Color
            Label {
                text: "Player Color:"
                font.bold: true
            }

            Row {
                spacing: 10
                Rectangle {
                    width: 50
                    height: 30
                    color: player.color
                    border.color: "black"
                    border.width: 1
                    radius: 5
                }
                
                Button {
                    text: "Change Color"
                    onClicked: colorDialog.open()
                }
            }

            // Player Avatar/Logo Index
            Label {
                text: "Player Avatar:"
                font.bold: true
            }

            ComboBox {
                id: avatarComboBox
                Layout.fillWidth: true
                
                model: [
                    { value: 0, text: "Avatar 1" },
                    { value: 1, text: "Avatar 2" },
                    { value: 2, text: "Avatar 3" },
                    { value: 3, text: "Avatar 4" },
                    { value: 4, text: "Avatar 5" },
                    { value: 5, text: "Avatar 6" }
                ]
                
                textRole: "text"
                valueRole: "value"
                currentIndex: player.indexLogo
                
                onCurrentValueChanged: {
                    if (currentValue !== undefined) {
                        player.indexLogo = currentValue
                    }
                }
            }

            // Player Money (Kibble)
            Label {
                text: "Player Kibble (Money):"
                font.bold: true
            }

            SpinBox {
                id: kibbleSpinBox
                Layout.fillWidth: true
                from: 0
                to: 99999
                stepSize: 50
                value: player.kibble
                
                onValueChanged: {
                    player.kibble = value
                }
            }

            // Player Position
            Label {
                text: "Player Position:"
                font.bold: true
            }

            SpinBox {
                id: positionSpinBox
                Layout.fillWidth: true
                from: 0
                to: 39  // Standard monopoly board has 40 positions (0-39)
                value: player.position
                
                onValueChanged: {
                    player.position = value
                }
            }

            // Player Jail Status
            CheckBox {
                text: "Player is in jail"
                checked: player.inJail
                onCheckedChanged: {
                    player.inJail = checked
                }
            }

            // Player Info Display
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                border.color: "#cccccc"
                border.width: 1
                color: "#f0f8ff"
                radius: 5
                
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 5
                    
                    Label {
                        text: "Player Information:"
                        font.bold: true
                        font.pixelSize: 14
                    }
                    
                    Label {
                        text: "Name: " + player.name
                        font.pixelSize: 12
                    }
                    
                    Label {
                        text: "Color: " + player.color
                        font.pixelSize: 12
                    }
                    
                    Label {
                        text: "Avatar Index: " + player.indexLogo
                        font.pixelSize: 12
                    }
                    
                    Label {
                        text: "Kibble: " + player.kibble
                        font.pixelSize: 12
                    }
                    
                    Label {
                        text: "Position: " + player.position + (player.inJail ? " (In Jail)" : "")
                        font.pixelSize: 12
                    }
                    
                    Label {
                        text: "Properties owned: " + player.propertyCount
                        font.pixelSize: 12
                    }
                }
            }
        }
    }

    // Color dialog for player color selection
    Dialog {
        id: colorDialog
        title: "Choose Player Color"
        width: 300
        height: 400
        modal: true

        Rectangle {
            anchors.fill: parent
            anchors.margins: 20

            Grid {
                anchors.fill: parent
                columns: 4
                spacing: 10

                property var colors: [
                    "#FF6B6B", "#4ECDC4", "#45B7D1", "#96CEB4",
                    "#FFEAA7", "#DDA0DD", "#98D8C8", "#F7DC6F",
                    "#BB8FCE", "#85C1E9", "#F8C471", "#82E0AA",
                    "#F1948A", "#85C1E9", "#D7BDE2", "#A9DFBF"
                ]

                Repeater {
                    model: parent.colors
                    
                    Rectangle {
                        width: 50
                        height: 50
                        color: modelData
                        border.color: "black"
                        border.width: 1
                        radius: 5

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                player.color = parent.color
                                colorDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }
}
