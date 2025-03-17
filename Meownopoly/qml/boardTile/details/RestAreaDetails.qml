import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ".."

ColumnLayout {
    id: root
    spacing: 5

    property var tileData
    property var familyColors: []

    Text {
        text: "Family: " + getFamilyName()
        font.pixelSize: 14
        color: "#2c3e50"
    }

    Text {
        text: "Owner: " + (root.tileData && root.tileData.owner ? root.tileData.owner : "None")
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
                restQuality: root.tileData && root.tileData.restQuality ? root.tileData.restQuality : 0
            }
        }
    }

    // Price information
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        visible: root.tileData && root.tileData.prices

        Text {
            text: "Purchase: " + (root.tileData && root.tileData.prices ? root.tileData.prices[0] + "K" : "N/A")
            font.pixelSize: 14
            color: "#2c3e50"
            font.bold: true
        }

        // Star prices in a grid
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
                    text: root.tileData && root.tileData.prices ? 
                          root.tileData.prices[index + 1] + "K" : "N/A"
                    font.pixelSize: 12
                    color: "#2c3e50"
                    font.bold: true
                }
            }
        }

        // Hotel price
        Text {
            text: "Hotel: " + (root.tileData && root.tileData.prices ? root.tileData.prices[5] + "K" : "N/A")
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
        return root.tileData && root.tileData.family >= 0 && root.tileData.family < families.length ? 
            families[root.tileData.family] : "None";
    }
} 