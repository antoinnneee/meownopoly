import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Game

Dialog {
    id: testDialog
    title: "TEST_VIEW_2 - Horizontal Flickable Cases"
    width: 900
    height: 600
    modal: true

    // Sample data for the tiles
    property var sampleTiles: [
        { name: "Rue Machin", price: 700, family: 1, type: 1 },
        { name: "CatDoor", price: 700, family: 0, type: 6 },
        { name: "Rue Machin", price: 650, family: 1, type: 1 },
        { name: "Rue Machin", price: 650, family: 1, type: 1 },
        { name: "Rue Machin", price: 500, family: 2, type: 1 },
        { name: "Rue Machin", price: 400, family: 2, type: 1 },
        { name: "Taxe", price: 1000, family: 0, type: 11 },
        { name: "Rue Machin", price: 400, family: 3, type: 1 },
        { name: "Rue Machin", price: 150, family: 3, type: 1 },
        { name: "Rue Machin", price: 150, family: 3, type: 1 },
        { name: "Rue Machin", price: 100, family: 3, type: 1 },
        { name: "Kibble Dispenser", price: 0, family: 0, type: 0 },
        { name: "Avenue Chat", price: 320, family: 4, type: 1 },
        { name: "Place Miaou", price: 280, family: 4, type: 1 },
        { name: "Catnip Corner", price: 250, family: 5, type: 1 },
        { name: "Fountain Plaza", price: 200, family: 5, type: 1 },
        { name: "Laser Street", price: 180, family: 6, type: 1 },
        { name: "Nap Avenue", price: 120, family: 6, type: 1 },
        { name: "Rest Area", price: 80, family: 7, type: 1 },
        { name: "Cardboard Box", price: 60, family: 7, type: 1 }
    ]

    // Colors for different family types
    property var familyColors: [
        "#ecf0f1",  // None
        "#795548",  // Brown
        "#81D4FA",  // Light Blue
        "#F48FB1",  // Pink
        "#FF9800",  // Orange
        "#e74c3c",  // Red
        "#F9E155",  // Yellow
        "#66BB6A",  // Green
        "#006064"   // Dark Blue
    ]

    // Icons for different tile types
    property var tileIcons: [
        appInstance.getAssetPath("kibble.png"),       // 0: Kibble Dispenser
        appInstance.getAssetPath("bed.png"),          // 1: Rest Area
        appInstance.getAssetPath("cardboard.png"),    // 2: Card Board Box
        appInstance.getAssetPath("catnip.png"),       // 3: Cat Nip
        appInstance.getAssetPath("jail.png"),         // 4: Jail
        appInstance.getAssetPath("tojail.png"),       // 5: To Jail
        appInstance.getAssetPath("catdoor.png"),      // 6: Cat Door
        appInstance.getAssetPath("nap.png"),          // 7: Free Nap
        appInstance.getAssetPath("fountain.png"),     // 8: Water Fountain
        appInstance.getAssetPath("laser.png"),        // 9: Laser Pointer
        appInstance.getAssetPath("tax.png"),          // 10: Golden Collar
        appInstance.getAssetPath("tax.png")           // 11: Fur Tax
    ]

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // Header
        Label {
            text: "Mode Horizontal - Cases Flickables"
            font.pixelSize: 20
            font.bold: true
            color: "#2c3e50"
            Layout.alignment: Qt.AlignHCenter
        }

        // Controls
        RowLayout {
            Layout.fillWidth: true
            
            Label {
                text: "Défilement horizontal des cases :"
                font.pixelSize: 14
                color: "#2c3e50"
            }
            
            Button {
                text: "Début"
                onClicked: flickable.contentX = 0
            }
            
            Button {
                text: "Fin"
                onClicked: flickable.contentX = flickable.contentWidth - flickable.width
            }
            
            Item { Layout.fillWidth: true }
            
            Label {
                text: "Zoom:"
                font.pixelSize: 14
                color: "#2c3e50"
            }
            
            Slider {
                id: zoomSlider
                from: 0.5
                to: 2.0
                value: 1.0
                Layout.preferredWidth: 150
            }
        }

        // Main content area with flickable tiles
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#34495e"
            radius: 10
            border.color: "#95a5a6"
            border.width: 2

            Flickable {
                id: flickable
                anchors.fill: parent
                anchors.margins: 10
                contentWidth: tilesRow.width
                contentHeight: tilesRow.height
                clip: true
                
                // Enable horizontal scrolling
                flickableDirection: Flickable.HorizontalFlick
                boundsBehavior: Flickable.StopAtBounds
                
                // Scrollbars
                ScrollBar.horizontal: ScrollBar {
                    policy: ScrollBar.AlwaysOn
                }

                Row {
                    id: tilesRow
                    spacing: 4
                    height: flickable.height - 20
                    
                    // Add some padding
                    Item {
                        width: 10
                        height: parent.height
                    }

                    Repeater {
                        model: sampleTiles
                        
                        Rectangle {
                            id: tileRect
                            width: 120 * zoomSlider.value
                            height: parent.height * 0.8
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#ecf0f1"
                            border.color: "#bdc3c7"
                            border.width: 1
                            radius: 6
                            
                            // Family color bar for rest areas
                            Rectangle {
                                id: colorBar
                                visible: modelData.type === 1
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: parent.top
                                }
                                height: parent.height * 0.15
                                color: modelData.family ? familyColors[modelData.family] : "#ecf0f1"
                                radius: 6
                                
                                Rectangle {
                                    width: parent.width
                                    height: parent.radius
                                    color: parent.color
                                    anchors.bottom: parent.bottom
                                }
                            }

                            Column {
                                anchors {
                                    left: parent.left
                                    right: parent.right
                                    top: colorBar.visible ? colorBar.bottom : parent.top
                                    bottom: parent.bottom
                                    margins: 8
                                }
                                spacing: 4

                                // Tile name
                                Text {
                                    id: nameText
                                    text: modelData.name
                                    color: "#2c3e50"
                                    font.pixelSize: Math.min(parent.width * 0.12, 11) * zoomSlider.value
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width
                                    elide: Text.ElideRight
                                    wrapMode: Text.WordWrap
                                }

                                // Icon
                                Image {
                                    id: tileIcon
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: Math.min(parent.width * 0.6, 40) * zoomSlider.value
                                    height: width
                                    source: modelData.type >= 0 && modelData.type < tileIcons.length ? 
                                           tileIcons[modelData.type] : ""
                                    sourceSize.width: width
                                    sourceSize.height: height
                                    fillMode: Image.PreserveAspectFit
                                    visible: status === Image.Ready
                                    asynchronous: true
                                    smooth: true
                                }

                                // Fallback icon
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    visible: !tileIcon.visible
                                    text: "🏠"
                                    font.pixelSize: Math.min(parent.width * 0.3, 25) * zoomSlider.value
                                }

                                // Price
                                Text {
                                    text: modelData.price > 0 ? modelData.price + "K" : ""
                                    color: "#2c3e50"
                                    font.pixelSize: Math.min(parent.width * 0.14, 12) * zoomSlider.value
                                    font.bold: true
                                    horizontalAlignment: Text.AlignHCenter
                                    width: parent.width
                                    visible: modelData.price > 0
                                }

                                // Family indicator
                                Rectangle {
                                    width: parent.width * 0.8
                                    height: 6
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    color: modelData.family ? familyColors[modelData.family] : "transparent"
                                    radius: 3
                                    visible: modelData.type === 1 && modelData.family > 0
                                }
                            }

                            // Hover effect
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: parent.color = "#d5dbdb"
                                onExited: parent.color = "#ecf0f1"
                                onClicked: {
                                    tileInfoDialog.tileData = modelData
                                    tileInfoDialog.open()
                                }
                            }
                        }
                    }
                    
                    // Add some padding at the end
                    Item {
                        width: 10
                        height: parent.height
                    }
                }
            }
        }

        // Status bar
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: "#95a5a6"
            radius: 4
            
            RowLayout {
                anchors.fill: parent
                anchors.margins: 8
                
                Label {
                    text: "Total cases: " + sampleTiles.length
                    color: "white"
                    font.pixelSize: 12
                }
                
                Item { Layout.fillWidth: true }
                
                Label {
                    text: "Position: " + Math.round(flickable.contentX) + " / " + Math.round(flickable.contentWidth - flickable.width)
                    color: "white"
                    font.pixelSize: 12
                }
            }
        }
    }

    // Tile info dialog
    Dialog {
        id: tileInfoDialog
        title: "Informations de la case"
        width: 300
        height: 200
        modal: true
        
        property var tileData: null
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10
            
            Label {
                text: "Nom: " + (tileInfoDialog.tileData ? tileInfoDialog.tileData.name : "")
                font.bold: true
            }
            
            Label {
                text: "Prix: " + (tileInfoDialog.tileData && tileInfoDialog.tileData.price > 0 ? 
                              tileInfoDialog.tileData.price + "K" : "Gratuit")
            }
            
            Label {
                text: "Famille: " + (tileInfoDialog.tileData && tileInfoDialog.tileData.family > 0 ? 
                               getFamilyName(tileInfoDialog.tileData.family) : "Aucune")
            }
            
            Label {
                text: "Type: " + (tileInfoDialog.tileData ? 
                             getTileTypeName(tileInfoDialog.tileData.type) : "")
            }
            
            Button {
                text: "Fermer"
                Layout.alignment: Qt.AlignHCenter
                onClicked: tileInfoDialog.close()
            }
        }
    }

    function getFamilyName(familyIndex) {
        const families = [
            "Aucune", "Marron", "Bleu clair", "Rose", "Orange", 
            "Rouge", "Jaune", "Vert", "Bleu foncé"
        ];
        return familyIndex >= 0 && familyIndex < families.length ? families[familyIndex] : "Inconnue";
    }

    function getTileTypeName(typeIndex) {
        const types = [
            "Distributeur de croquettes", "Zone de repos", "Boîte en carton", "Herbe à chat",
            "Prison", "Aller en prison", "Chatière", "Sieste gratuite", 
            "Fontaine", "Pointeur laser", "Collier doré", "Taxe poil"
        ];
        return typeIndex >= 0 && typeIndex < types.length ? types[typeIndex] : "Inconnu";
    }

    standardButtons: Dialog.Close
} 
