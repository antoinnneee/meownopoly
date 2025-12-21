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
        color: "#212121"
        border.color: "#4A90E2"
        border.width: 2
        anchors.centerIn: parent

        property int selectedBackground: -1
        property string selectedDisplayMode: "Fit"
        property string mapName: ""
        property bool snapToGrid: true

        // FileDialog pour image personnalisée
        FileDialog {
            id: customBackgroundDialog
            title: qsTr("Sélectionner une image personnalisée")
            nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]
            onAccepted: {
                newMapInfo.backgroundPath = customBackgroundDialog.selectedFile
                logic.mapInfo.backgroundPath = customBackgroundDialog.selectedFile
                menuMapAtStart.selectedBackground = -2
                console.log("Custom background set to: " + customBackgroundDialog.selectedFile)
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // Header with title
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 50
                Text {
                    Layout.alignment: Qt.AlignLeft
                    horizontalAlignment: Text.AlignLeft
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

            // Map description text field
            TextField {
                id: mapDescriptionField
                Layout.fillWidth: true
                Layout.preferredHeight: 60
                placeholderText: "Description de la carte (optionnel)"
                placeholderTextColor: "#888888"
                color: "#FFFFFF"
                font.pixelSize: 14
                wrapMode: TextInput.Wrap

                background: Rectangle {
                    color: "#333333"
                    radius: 8
                    border.width: mapDescriptionField.activeFocus ? 2 : 1
                    border.color: mapDescriptionField.activeFocus ? "#4A90E2" : "#555555"
                }

                onTextChanged: {
                    newMapInfo.mapDescription = text
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
                    id: backgroundSelectionLayout
                    anchors.fill: parent
                    spacing: 15

                    // Display mode label
                    Text {
                        text: "Mode d'affichage:"
                        color: "#FFFFFF"
                        font.pixelSize: 16
                    }

                    // Snap to grid checkbox - EN PREMIER
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
                                newMapInfo.backgroundScaling = "Stretch"
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
                                newMapInfo.backgroundScaling = "Fit"
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
                                    newMapInfo.backgroundScaling = "Tile"
                                }
                            }

                            Slider {
                                id: tileSizeSlider
                                Layout.fillWidth: true
                                from: 20
                                to: 400
                                stepSize: 20
                                value: 100
                                visible: enabled
                                enabled: menuMapAtStart.selectedDisplayMode === "Tile"

                                onValueChanged: {
                                    logic.mapInfo.backgroundTileSize = value
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

                    // Zone scrollable pour la sélection d'arrière-plan
                    Flickable {
                        id: backgroundFlickable
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: scrollableContent.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        // ScrollBar verticale
                        ScrollBar.vertical: ScrollBar {
                            id: backgroundScrollBar
                            policy: ScrollBar.AsNeeded
                            active: true
                            interactive: true

                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: width / 2
                                color: backgroundScrollBar.pressed ? "#888888" : "#666666"
                                opacity: backgroundScrollBar.active ? 1.0 : 0.5
                            }
                        }

                        Column {
                            id: scrollableContent
                            width: backgroundFlickable.width - 10
                            spacing: 15

                            // Background selection label
                            Text {
                                text: "Sélectionner un arrière-plan:"
                                color: "#FFFFFF"
                                font.pixelSize: 14
                            }

                            // Option image personnalisée
                            Rectangle {
                                width: parent.width
                                height: 80
                                radius: 8
                                color: "#2a2a2a"
                                border.width: menuMapAtStart.selectedBackground === -2 ? 3 : 1
                                border.color: menuMapAtStart.selectedBackground === -2 ? "#E91E63" : "#555555"

                                Row {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 12

                                    // Zone d'aperçu / sélection
                                    Rectangle {
                                        width: 64
                                        height: 64
                                        radius: 6
                                        color: "#333333"
                                        border.color: customImageMouseArea.containsMouse ? "#E91E63" : "#444444"
                                        border.width: customImageMouseArea.containsMouse ? 2 : 1

                                        // Icône caméra
                                        Column {
                                            anchors.centerIn: parent
                                            spacing: 2
                                            visible: menuMapAtStart.selectedBackground !== -2

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "📷"
                                                font.pixelSize: 24
                                                color: "#AAAAAA"
                                            }

                                            Text {
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                text: "Parcourir"
                                                font.pixelSize: 9
                                                color: "#888888"
                                            }
                                        }

                                        // Aperçu de l'image sélectionnée
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            visible: menuMapAtStart.selectedBackground === -2 && newMapInfo.backgroundPath !== ""
                                            source: newMapInfo.backgroundPath
                                            fillMode: Image.PreserveAspectCrop
                                        }

                                        MouseArea {
                                            id: customImageMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: customBackgroundDialog.open()
                                        }
                                    }

                                    // Texte descriptif
                                    Column {
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: 4
                                        width: parent.width - 76 - 40 - parent.spacing * 2

                                        Text {
                                            text: "Image personnalisée"
                                            color: "#FFFFFF"
                                            font.pixelSize: 13
                                            font.bold: true
                                        }

                                        Text {
                                            text: menuMapAtStart.selectedBackground === -2 && newMapInfo.backgroundPath !== ""
                                                  ? newMapInfo.backgroundPath.toString().substring(newMapInfo.backgroundPath.toString().lastIndexOf("/") + 1)
                                                  : "Cliquez pour choisir une image"
                                            color: "#AAAAAA"
                                            font.pixelSize: 11
                                            width: parent.width
                                            elide: Text.ElideMiddle
                                        }
                                    }

                                    // Bouton de suppression
                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 12
                                        color: "#CC2222"
                                        visible: menuMapAtStart.selectedBackground === -2 && newMapInfo.backgroundPath !== ""
                                        anchors.verticalCenter: parent.verticalCenter
                                        opacity: removeCustomMouseArea.containsMouse ? 1.0 : 0.7

                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            font.pixelSize: 16
                                            font.bold: true
                                            color: "white"
                                        }

                                        MouseArea {
                                            id: removeCustomMouseArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                newMapInfo.backgroundPath = ""
                                                logic.mapInfo.backgroundPath = ""
                                                menuMapAtStart.selectedBackground = -1
                                            }
                                        }
                                    }
                                }
                            }

                            // Séparateur
                            Row {
                                width: parent.width
                                spacing: 10

                                Rectangle {
                                    width: (parent.width - orText.width - 20) / 2
                                    height: 1
                                    color: "#444444"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    id: orText
                                    text: "ou"
                                    color: "#666666"
                                    font.pixelSize: 11
                                }
                                Rectangle {
                                    width: (parent.width - orText.width - 20) / 2
                                    height: 1
                                    color: "#444444"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }

                            // Liste des thèmes par défaut
                            Repeater {
                                id: backgroundRepeater
                                model: AssetManager.getAvailableBackgrounds()

                                Rectangle {
                                    width: scrollableContent.width
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
                                            text: {
                                                var path = modelData;
                                                var fileName = path.substring(path.lastIndexOf("/") + 1);
                                                return fileName.replace(/\.[^/.]+$/, "");
                                            }
                                            color: "white"
                                            font.pixelSize: 14
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            menuMapAtStart.selectedBackground = index
                                            logic.mapInfo.backgroundPath = bgImage.source
                                            newMapInfo.backgroundPath = bgImage.source
                                            newMapInfo.backgroundScaling = menuMapAtStart.selectedDisplayMode
                                            logic.mapInfo.backgroundScaling = menuMapAtStart.selectedDisplayMode
                                            console.log("Background path set to: " + newMapInfo.backgroundPath)
                                        }
                                    }
                                }
                            }

                            // Espace en bas pour le scroll
                            Item {
                                width: parent.width
                                height: 10
                            }
                        }
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
                        color: "#4CAF50"
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
                        color: "#F44336"
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
