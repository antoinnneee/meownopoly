import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "./details"

Popup {
    id: root
    width: 300
    height: 400
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: Overlay.overlay

    property int tileType: -1
    property string tileName: ""
    property var tileData: null
    property var familyColors: []

    contentItem: Rectangle {
        color: "#ecf0f1"
        border.color: "#bdc3c7"
        border.width: 1
        radius: 8

        ColumnLayout {
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 10

            // Title bar
            Rectangle {
                Layout.fillWidth: true
                height: 40
                color: root.tileType === 1 && root.tileData && root.tileData.family ? 
                       root.familyColors[root.tileData.family] : "#34495e"
                radius: 4

                Text {
                    anchors.centerIn: parent
                    text: root.tileName
                    color: "white"
                    font.pixelSize: 18
                    font.bold: true
                }
            }

            // Tile icon
            Item {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 60
                Layout.preferredHeight: 60
                
                Image {
                    anchors.fill: parent
                    source: root.tileType >= 0 ? "qrc:/asset/" + getTileIconName() : ""
                    sourceSize {
                        width: width * 2
                        height: height * 2
                    }
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    antialiasing: true
                    visible: status === Image.Ready
                    asynchronous: true
                }
            }

            // Tile type
            Text {
                text: "Type: " + getTileTypeName()
                font.pixelSize: 14
                color: "#2c3e50"
                Layout.bottomMargin: 10
            }

            // Specific tile details
            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: {
                    switch(root.tileType) {
                        case 1: return restAreaDetails
                        case 0: return kibbleDispenserDetails
                        case 4: return jailDetails
                        default: return null
                    }
                }
            }

            // Close button
            Button {
                text: "Close"
                Layout.alignment: Qt.AlignHCenter
                onClicked: root.close()
                
                background: Rectangle {
                    color: parent.pressed ? "#95a5a6" : "#7f8c8d"
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }

    // Components for different tile types
    Component {
        id: restAreaDetails
        RestAreaDetails {
            tileData: root.tileData
            familyColors: root.familyColors
        }
    }

    Component {
        id: kibbleDispenserDetails
        KibbleDispenserDetails {}
    }

    Component {
        id: jailDetails
        JailDetails {}
    }

    function getTileTypeName() {
        const tileTypes = [
            "Kibble Dispenser", "Rest Area", "Card Board Box", "Cat Nip",
            "Jail", "Go To Jail", "Cat Door", "Free Nap", 
            "Water Fountain", "Laser Pointer", "Golden Collar", "Fur Tax"
        ];
        return root.tileType >= 0 && root.tileType < tileTypes.length ? tileTypes[root.tileType] : "Unknown";
    }

    function getTileIconName() {
        const icons = [
            "kibble.png", "bed.png", "cardboard.png", "catnip.png",
            "jail.png", "tojail.png", "catdoor.png", "nap.png",
            "fountain.png", "laser.png", "tax.png", "tax.png"
        ];
        return root.tileType >= 0 && root.tileType < icons.length ? icons[root.tileType] : "";
    }
}
