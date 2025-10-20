import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Dialogs
import QtCore

import "tools"
import "tools/snapable"
import "panel"
import "panel/assetSelectionPanel"

import QtQml
import Game
import Case
import ItemSnapable
import MapFileManager 1.0`nimport MapTypes 1.0
import MapInfo
import EditorEnum
import AssetManager 1.0

MouseArea {
    anchors.fill: parent
    id: root
    signal backgroundSelected()


    onClicked: {
        var mappedPoint = root.mapToItem(menuMapAtStart, mouseX, mouseY)
        if (!menuMapAtStart.contains(mappedPoint)) {
            menuMapAtStart.opacity = 0.15
        } else {
            menuMapAtStart.opacity = 1.0
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
        property string selectedMap: ""
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

                Button {
                    id: displayMenuBtn
                    Layout.alignment: Qt.AlignRight
                    Layout.rightMargin: 0
                    background: Rectangle {
                        color: displayMenuBtn.checked ? "#4A90E2" : "#333333"
                        radius: 8
                        border.width: 1
                        border.color: displayMenuBtn.checked ? "#FFFFFF" : "#555555"
                    }
                    contentItem: Text {
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        text: displayMenuBtn.checked ? "Afficher la prochaine fois" : "Ne plus afficher"
                        color: "white"
                        font.pixelSize: 13
                    }
                    onClicked:{
                        displayMenuBtn.checked = !displayMenuBtn.checked
                        stBackGroundEditor.setValue("showBackground", checked)
                        stBackGroundEditor.sync()
                    }
                    Component.onCompleted: {
                        displayMenuBtn.checked = stBackGroundEditor.value("showBackground", "true")
                    }
                    Settings {
                        id: stBackGroundEditor
                        category: "showBackgroundEditor"
                        property bool showBackground: stBackGroundEditor.value("showBackground", "true")
                        Component.onCompleted: {
                            root.visible = showBackground
                            root.enabled = showBackground
                        }
                    }
                }
            }

            // Header buttons
            Row {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                spacing: 10

                Button {
                    id: chooseBackgroundBtn
                    text: "Nouvelle Carte"

                    width: parent.width / 2 - 5
                    height: parent.height
                    checked: true

                    background: Rectangle {
                        color: chooseBackgroundBtn.checked ? "#4A90E2" : "#333333"
                        radius: 8
                        border.width: 1
                        border.color: chooseBackgroundBtn.checked ? "#FFFFFF" : "#555555"
                    }

                    contentItem: Text {
                        text: chooseBackgroundBtn.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 17
                    }

                    onClicked: {
                        chooseBackgroundBtn.checked = true
                        loadMapBtn.checked = false
                        backgroundContent.visible = true
                        loadMapContent.visible = false
                    }
                }

                Button {
                    id: loadMapBtn
                    text: "Charger une carte"
                    font.bold: true

                    width: parent.width / 2 - 5
                    height: parent.height
                    checked: false

                    enabled : MapFileManager.getAvailableMaps().length > 0
                    opacity : enabled ? 1.0 : 0.5
                    background: Rectangle {
                        color: loadMapBtn.checked ? "#4A90E2" : "#333333"
                        radius: 8
                        border.width: 1
                        border.color: loadMapBtn.checked ? "#FFFFFF" : "#555555"
                    }

                    contentItem: Text {
                        text: loadMapBtn.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 17
                    }

                    onClicked: {
                        chooseBackgroundBtn.checked = false
                        loadMapBtn.checked = true
                        backgroundContent.visible = false
                        loadMapContent.visible = true
                    }
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
                                    if (typeof logic !== 'undefined' && typeof logic.mapInfo !== 'undefined') {
                                        logic.mapInfo.backgroundTileSize = value
                                    }
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
                                    menuMapAtStart.selectedBackground = index

                                    // Mettre à jour les propriétés de mapInfo si logic est disponible
                                    if (typeof logic !== 'undefined' && typeof logic.mapInfo !== 'undefined') {
                                        // Définir le chemin de l'image de fond
                                        logic.mapInfo.backgroundPath = bgImage.source

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
                                        logic.mapInfo.backgroundScaling = scaling;
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
                            menuMapAtStart.snapToGrid = checked
                            logic.mapInfo.isBackgroundOnGrill = checked
                        }
                    }
                }
            }

            // Load map content
            Rectangle {
                id: loadMapContent
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                visible: false

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    // Maps container
                    Rectangle {
                        id: mapsContainer
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "#2A2A2A"
                        radius: 8
                        border.color: "#4A90E2"
                        border.width: 1

                        // Header avec titre
                        Rectangle {
                            id: headerSection
                            width: parent.width
                            height: 42
                            color: "#383838"
                            radius: 8
                            anchors.top: parent.top
                            anchors.topMargin: 1
                            anchors.horizontalCenter: parent.horizontalCenter

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                spacing: 10

                                Rectangle {
                                    width: 28
                                    height: 28
                                    radius: 14
                                    color: "#4A90E2"
                                    opacity: 0.3

                                    Text {
                                        anchors.centerIn: parent
                                        text: "🗺️"
                                        font.pixelSize: 16
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Cartes disponibles"
                                    color: "white"
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                            }
                        }

                        // Liste des maps
                        ListView {
                            id: mapsList
                            anchors.top: headerSection.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: 10
                            model: []
                            spacing: 8
                            clip: true
                            focus: true
                            interactive: true
                            boundsBehavior: Flickable.StopAtBounds

                            Component.onCompleted: {
                                model = MapFileManager.getAvailableMaps()
                            }

                            ScrollBar.vertical: ScrollBar {
                                id: scrollBar
                                active: mapsList.contentHeight > mapsList.height
                                policy: ScrollBar.AsNeeded
                                visible: mapsList.contentHeight > mapsList.height
                                interactive: true

                                contentItem: Rectangle {
                                    implicitWidth: 8
                                    radius: width / 2
                                    color: "#4A90E2"
                                    opacity: scrollBar.pressed ? 0.8 : 0.5
                                }
                            }

                            delegate: Rectangle {
                                width: mapsList.width
                                height: 40
                                color: menuMapAtStart.selectedMap === modelData ? "#3A5998" : "#333333"
                                radius: 4

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    spacing: 10

                                    Rectangle {
                                        width: 24
                                        height: 24
                                        radius: 4
                                        color: "#4A90E2"
                                        opacity: 0.2
                                        anchors.verticalCenter: parent.verticalCenter

                                        Text {
                                            anchors.centerIn: parent
                                            text: "📄"
                                            font.pixelSize: 14
                                        }
                                    }

                                    Text {
                                        text: modelData
                                        color: "white"
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        console.log("Selected map: " + modelData)
                                        menuMapAtStart.selectedMap = modelData
                                    }
                                }
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
                        if (backgroundContent.visible /*&& menuMapAtStart.selectedBackground !== -1*/) {
                            root.visible = false
                            root.backgroundSelected()
                        }
                        else if (loadMapContent.visible && menuMapAtStart.selectedMap !== "") {
                            console.log("Loading map: " + menuMapAtStart.selectedMap)
                            if (typeof logic !== 'undefined') {
                                logic.removeCurrentMap()
                                var normalizedMapName = MapFileManager.findMapFileByName(menuMapAtStart.selectedMap)
                                if (normalizedMapName !== "") {
                                    Game.loadMap(normalizedMapName, MapTypes.CUSTOM)
                                } else {
                                    console.error("Could not find map file for: " + menuMapAtStart.selectedMap)
                                }
                            }
                            root.visible = false
                        }
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
                        mapInfo.backgroundPath = ""
                        mapInfo.backgroundScaling = "Fit"
                    }
                }
            }
        }

        Component.onCompleted: {
            visible = true
        }
    }
}

