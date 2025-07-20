import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import "./details"

Popup {
    id: root
    width: 300
    height: 400
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    anchors.centerIn: Overlay.overlay

    required property Case caseData

    property int tileType: caseData.type
    property string tileName: ""
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
                color: root.tileType === 1 && root.caseData && root.caseData.family ?
                       root.familyColors[root.caseData.family] : "#34495e"
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
                text: "Type: " + root.getTileTypeName()
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
                        case Case.CS_RestArea: return restAreaDetails
                        case Case.CS_KibbleDispenser: return kibbleDispenserDetails
                        case Case.CS_CardBoardBox: return cardBoardBoxDetails
                        case Case.CS_CatNip: return catNipDetails
                        case Case.CS_Jail: return jailDetails
                        case Case.CS_ToJail: return toJailDetails
                        case Case.CS_CatDoor: return catDoorDetails
                        case Case.CS_FreeNap: return freeNapDetails
                        case Case.CS_Device: return catDeviceDetails
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
            caseData: (root.caseData.type === Case.CS_RestArea) ? root.caseData : null
            familyColors: root.familyColors
        }
    }

    Component {
        id: kibbleDispenserDetails
        KibbleDispenserDetails {
            caseData: (root.caseData.type === Case.CS_KibbleDispenser) ? root.caseData : null
        }
    }

    Component {
        id: cardBoardBoxDetails
        CardBoardBoxDetails {
            caseData: (root.caseData.type === Case.CS_CardBoardBox) ? root.caseData : null
        }
    }

    Component {
        id: catNipDetails
        CatNipDetails {
            caseData: (root.caseData.type === Case.CS_CatNip) ? root.caseData : null
        }
    }

    Component {
        id: jailDetails
        JailDetails {}
    }

    Component {
        id: toJailDetails
        ToJailDetails {
            caseData: (root.caseData.type === Case.CS_ToJail) ? root.caseData : null
        }
    }

    Component {
        id: catDoorDetails
        CatDoorDetails {
            caseData: (root.caseData.type === Case.CS_CatDoor) ? root.caseData : null
        }
    }

    Component {
        id: freeNapDetails
        FreeNapDetails {
            caseData: (root.caseData.type === Case.CS_FreeNap) ? root.caseData : null
        }
    }

    Component {
        id: catDeviceDetails
        CatDeviceDetails {
            caseData: (root.caseData.type === Case.CS_Device) ? root.caseData : null
        }
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
