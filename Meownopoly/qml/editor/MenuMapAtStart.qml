import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Dialogs
import QtCore

import "../component"
import "../component/snapable"
import "../component/grid"
import "panel"
import assetSelectionPanel

import QtQml
import Case
import ItemSnapable
import MapInfo
import MapFileManager
import MapTypes
import EditorEnum
import AssetManager 1.0

MouseArea {
    id: root
    anchors.fill: parent

    required property var logic

    signal backgroundSelected()
    signal newMapSet()

    property var newMapInfo: MapInfo {
        id: mapInfo
    }

    onClicked: {
        var mappedPoint = root.mapToItem(menuMapAtStart, mouseX, mouseY)
        if (!menuMapAtStart.contains(mappedPoint)) {
            // Fermer le menu si on clique en dehors
            root.visible = false
            root.enabled = false
        }
    }

    Rectangle {
        id: menuMapAtStart
        width: parent.width * 0.5
        height: width
        radius: 15
        color: "#212121" // Darker background
        border.color: "#4A90E2"
        border.width: 2
        anchors.centerIn: parent

        // Signal to show InfoPanel when confirmed - will be connected in Editor.qml

        property int selectedBackground: -1
        property string selectedDisplayMode: "Fit"
        property string mapName: ""
        property bool snapToGrid: true

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header with title
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                // color: "transparent"
                Text {
                    Layout.alignment: Qt.AlignLeft
                    horizontalAlignment: Text.AlignLeft
                    // anchors.centerIn: parent
                    text: "Configuration de la carte"
                    color: "#FFFFFF"
                    font.pixelSize: 20
                    font.bold: true
                }
                Item {
                    Layout.fillWidth: true
                }

            }

            // Map name text field
            TextField {
                id: mapNameField
                property bool mapnameExists: false
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                placeholderText: mapnameExists ? "Nom de carte deja utilise" : "Nom de la nouvelle carte"
                placeholderTextColor: mapnameExists ? "lightred" : "#888888"
                color: "#FFFFFF"
                font.pixelSize: 16
                background: Rectangle {
                    color: "#333333"
                    radius: 8
                    border.width: mapNameField.activeFocus ? 2 : 1
                    border.color: !mapNameField.activeFocus ? "#555555" : mapNameField.mapnameExists ? "red" : "#4A90E2"
                }

                onTextChanged: {
                    if (MapFileManager.mapExists(text, MapTypes.CUSTOM))
                        mapNameField.mapnameExists = true

                    else
                        mapNameField.mapnameExists = false

                    newMapInfo.mapName = text
                }
            }

            // Background selection content
            Rectangle {
                id: backgroundContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                visible: true

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 20

                    // Display mode label
                    Text {
                        text: "Mode d'affichage:"
                        color: "#FFFFFF"
                        font.pixelSize: 16
                    }

                    // Display mode buttons
                    Row {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        spacing: 10

                        Button {
                            text: "Stretch"
                            font.pixelSize: 14
                            width: (parent.width - 20) / 3
                            height: parent.height

                            background: Rectangle {
                                color: menuMapAtStart.selectedDisplayMode === "Stretch" ? "#4A90E2" : "#333333"
                                radius: 6
                            }

                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                menuMapAtStart.selectedDisplayMode = "Stretch"
                                mapInfo.backgroundScaling = "Stretch"
                            }
                        }

                        Button {
                            id: fitButton
                            text: "Fit"
                            font.pixelSize: 14
                            width: (parent.width - 20) / 3
                            height: parent.height

                            background: Rectangle {
                                color: menuMapAtStart.selectedDisplayMode === "Fit" ? "#4A90E2" : "#333333"
                                radius: 6
                            }

                            contentItem: Text {
                                text: parent.text
                                color: "white"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                menuMapAtStart.selectedDisplayMode = "Fit"
                                mapInfo.backgroundScaling = "Fit"

                            }
                        }

                        ColumnLayout {
                            width: (parent.width - 20) / 3
                            spacing: 4

                            Button {
                                text: "Tile"
                                font.pixelSize: 14
                                Layout.fillWidth: true
                                Layout.maximumHeight: fitButton.height

                                background: Rectangle {
                                    color: menuMapAtStart.selectedDisplayMode === "Tile" ? "#4A90E2" : "#333333"
                                    radius: 6
                                }

                                contentItem: Text {
                                    text: parent.text
                                    color: "white"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    menuMapAtStart.selectedDisplayMode = "Tile"
                                    mapInfo.backgroundScaling = "Tile"
                                }
                            }

                            Slider {
                                id: tileSizeSlider
                                Layout.fillWidth: true
                                from: 20
                                to: 400
                                stepSize: 20
                                value: 100
                                visible : enabled
                                enabled: menuMapAtStart.selectedDisplayMode === "Tile"

                                onValueChanged: {
                                    logic.mapInfo.backgroundTileSize = value
                                    console.log("Tile Size changed to: " + value)
                                    newMapInfo.backgroundTileSize = value
                                }

                                background: Rectangle {
                                    x: tileSizeSlider.leftPadding
                                    y: tileSizeSlider.topPadding + tileSizeSlider.availableHeight / 2 - height / 2
                                    width: tileSizeSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: "#333333"

                                    Rectangle {
                                        width: tileSizeSlider.visualPosition * parent.width
                                        height: parent.height
                                        color: "#4A90E2"
                                        radius: 2
                                    }
                                }
                                handle: Rectangle {
                                    x: tileSizeSlider.leftPadding + tileSizeSlider.visualPosition * (tileSizeSlider.availableWidth - width)
                                    y: tileSizeSlider.topPadding + tileSizeSlider.availableHeight / 2 - height / 2
                                    width: 16
                                    height: 16
                                    radius: 8
                                    color: tileSizeSlider.pressed ? "#FFFFFF" : "#F0F0F0"
                                    border.color: "#4A90E2"
                                }
                            }
                        }
                    }

                    // Background selection label
                    Text {
                        text: "Sélectionner un arrière-plan:"
                        color: "#FFFFFF"
                        font.pixelSize: 14
                    }

                    // Background ListView
                    ListView {
                        id: listBackGround
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 10
                        clip: true

                        model: AssetManager.getAvailableBackgrounds()

                        delegate: Rectangle {
                            width: listBackGround.width
                            height: 90
                            radius: 8
                            border.width: menuMapAtStart.selectedBackground === index ? 3 : 1
                            border.color: menuMapAtStart.selectedBackground === index ? "#4A90E2" : "#555555"

                            Image {
                                id: bgImage
                                anchors.fill: parent
                                anchors.margins: 2
                                source: modelData
                                fillMode: Image.PreserveAspectCrop
                            }

                            // Caption overlay
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 26
                                color: "#80000000"

                                Text {
                                    anchors.centerIn: parent
                                    // Extraire le nom du fichier à partir du chemin complet et enlever l'extension
                                    text: {
                                        var path = modelData;
                                        var fileName = path.substring(path.lastIndexOf("/") + 1);
                                        return fileName.replace(/\.[^/.]+$/, ""); // Enlever l'extension
                                    }
                                    color: "white"
                                    font.pixelSize: 14
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    logic.mapInfo.backgroundPath = bgImage.source
                                    newMapInfo.backgroundPath = bgImage.source
                                    console.log("Background path set to: " + newMapInfo.backgroundPath);



                                    // Définir le mode de mise à l'échelle en fonction du mode sélectionné
                                    var scaling;
                                    switch(menuMapAtStart.selectedDisplayMode) {
                                    case "Stretch":
                                        scaling = "Stretch";
                                        break;
                                    case "Fit":
                                        scaling = "Fit";
                                        break;
                                    case "Tile":
                                        scaling = "Tile";
                                        break;
                                    default:
                                        scaling = "Fit"; // Valeur par défaut
                                    }
                                    logic.mapInfo.backgroundScaling = scaling
                                    newMapInfo.backgroundScaling = scaling;
                                    console.log("Background scaling set to: " + newMapInfo.backgroundScaling);
                                }
                            }
                        }
                    }
                }

                // Snap to grid checkbox
                CheckBox {
                    id: snapToGridCheckBox
                    text: "Fixé à la grille ?"
                    Layout.fillWidth: true
                    checked: menuMapAtStart.snapToGrid

                    indicator: Rectangle {
                        implicitWidth: 20
                        implicitHeight: 20
                        x: snapToGridCheckBox.leftPadding
                        y: parent.height / 2 - height / 2
                        radius: 3
                        border.color: "#4A90E2"
                        border.width: 1
                        color: snapToGridCheckBox.checked ? "#4A90E2" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "✓"
                            font.pixelSize: 14
                            color: "white"
                            visible: snapToGridCheckBox.checked
                        }
                    }

                    contentItem: Text {
                        text: snapToGridCheckBox.text
                        font.pixelSize: 14
                        color: "#FFFFFF"
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: snapToGridCheckBox.indicator.width + snapToGridCheckBox.spacing
                    }

                    onCheckedChanged: {
                        newMapInfo.isBackgroundOnGrill = checked
                        logic.mapInfo.isBackgroundOnGrill = checked
                    }

                }
            }

            // Bottom action buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                spacing: 12

                Button {
                    text: "Confirmer"
                    Layout.fillWidth: true

                    background: Rectangle {
                        color: "#4CAF50"  // Green color
                        radius: 8
                        border.width: 1
                        border.color: "#FFFFFF"
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 14
                        font.bold: true
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        if (newMapInfo.mapName === "" || MapFileManager.mapExists(newMapInfo.mapName, MapTypes.CUSTOM)){
                            console.log("Map name is invalid or already exists.")
                            return
                        }

                        root.visible = false
                        root.enabled = false
                        root.backgroundSelected()
                        root.newMapSet()
                    }
                }

                Button {
                    text: "Annuler"
                    Layout.fillWidth: true

                    background: Rectangle {
                        color: "#F44336"  // Red color
                        radius: 8
                        border.width: 1
                        border.color: "#FFFFFF"
                    }

                    contentItem: Text {
                        text: parent.text
                        font.pixelSize: 14
                        font.bold: true
                        color: "#FFFFFF"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.visible = false
                        root.enabled = false
                        mapInfo.backgroundPath = ""
                        mapInfo.backgroundScaling = "Fit"
                    }
                }
            }
        }
    }
}
