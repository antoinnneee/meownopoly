import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game
import CaseRestArea
import Case
import "../case"

Dialog {
    title: "Test Case"
    width: 600
    height: 400

    property Case caseInfo: null
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
                text: caseInfo.name
                placeholderText: "Enter case name"
                onTextChanged: {
                    caseInfo.name = text
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
                        console.log(currentValue);
                       caseInfo = Game.getNewCaseType(currentValue);
                        console.log("price : ", caseInfo.price)
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
    }
}
