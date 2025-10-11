import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import CaseRestArea
import Player
import ".."

ColumnLayout {
    id: root
    spacing: 5

    required property CaseRestArea caseData
    property var familyColors: []

    Text {
        text: "Family: " + root.getFamilyName()
        font.pixelSize: 14
        color: "#2c3e50"
    }

    Text {
        text: (root.caseData === null) ? "null" :
                                                     root.caseData.owner != undefined ? root.caseData.owner.name
                                                                                      : "no owner"
        font.pixelSize: 14
        color: "#2c3e50"
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 5

        Text {
            text: "Rest Quality:"
            font.pixelSize: 14
            color: "#2c3e50"
        }

        Item {
            Layout.preferredWidth: 120
            Layout.preferredHeight: 30
            
            StarRating {
                anchors.fill: parent
                anchors.margins: 2
                restQuality: (root.caseData) ? root.caseData.restQuality : CaseRestArea.RQ_NONE
            }
        }
    }

    // Price information
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        visible: root.caseData

        Text {
            text: "Purchase: " + (root.caseData && root.caseData.price ? root.caseData.price + "K" : "N/A")
            font.pixelSize: 14
            color: "#2c3e50"
            font.bold: true
        }

        // Star rentPrice in a grid
        Grid {
            Layout.fillWidth: true
            columns: 4
            spacing: 10

            Repeater {
                model: 4
                Text {
                    width: (parent.width - parent.spacing * 3) / 4
                    horizontalAlignment: Text.AlignHCenter
                    text: (index + 1) + (index === 0 ? " star" : " stars")
                    font.pixelSize: 12
                    color: "#2c3e50"
                }
            }

            Repeater {
                model: 4
                Text {
                    width: (parent.width - parent.spacing * 3) / 4
                    horizontalAlignment: Text.AlignHCenter
                    text: root.caseData && root.caseData.rentPrice ?
                          root.caseData.rentPrice[index + 1] + "K" : "N/A"
                    font.pixelSize: 12
                    color: "#2c3e50"
                    font.bold: true
                }
            }
        }

        // Hotel price
        Text {
            text: (root.caseData) ?"Hotel :" +  root.caseData.rentPrice[5] : "N/A"
            font.pixelSize: 14
            color: "#2c3e50"
            font.bold: true
            Layout.alignment: Qt.AlignRight
        }
    }

    function getFamilyName() {
        const families = [
            "None", "Brown", "Light Blue", "Pink", "Orange", 
            "Red", "Yellow", "Green", "Dark Blue"
        ];
        return root.caseData && root.caseData.family >= 0 && root.caseData.family < families.length ?
            families[root.caseData.family] : "None";
    }
} 
