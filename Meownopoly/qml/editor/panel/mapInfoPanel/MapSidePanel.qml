import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore
import QtQuick.Dialogs
import Case
import ItemSnapable
import ui_item 1.0
import "../../../component"

import Game
import MapFileManager
import MapTypes
import MapInfo
import EditorEnum
import Logger
import DisplayParameter
import DecorationParameter
import ItemSnapableFactory
import UndoRedoManager
import AssetManager

Rectangle {
    id: mapSidePanel
    anchors.top: parent.top
    anchors.topMargin: 25
    height: Screen.pixelDensity * 150
    width: Screen.pixelDensity * 75
    color: "#333333"
    radius: 6
    border.color: "#4A90E2"
    border.width: 1
    x: parent.width

    signal refreshPanel()

    onRefreshPanel: {
            console.log("Refreshing Map Side Panel with map name: " + logic.mapInfo.mapName)
            mapNameInput.text = logic.mapInfo.mapName
    }

    Behavior on x {
        NumberAnimation {
            duration: 500
            easing.type: Easing.InOutQuad
            onFinished: {
                if (mapSidePanel.x >= parent.width) {
                    mapInfoPanel.visible = false
                }
            }
        }
    }
    // Header avec titre
    Rectangle {
        id: headerSection
        width: parent.width*0.9
        height: 32
        color: "#383838"
        radius: 4
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter

        Row {
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: 6
            spacing: 6

            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: "#4A90E2"
                opacity: 0.2

                Text {
                    anchors.centerIn: parent
                    text: mapInfoPanel.currentView === 0 ? "🗺️" : "🖼️"
                    font.pixelSize: 10
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: mapInfoPanel.currentView === 0 ? "Infos carte" : "Fond d'écran"
                color: "white"
                font.pixelSize: 10
                font.bold: true
            }
        }

        // Bouton fermer
        Button {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 6
            width: 24
            height: 24
            text: "✕"
            background: Rectangle {
                color: parent.hovered ? "#555555" : "transparent"
                radius: 3
            }

            onClicked: {
                isOpening = false
                selectionPanel.visible =  selectionPanel.visible ? false: true
                sidePanel.visible = sidePanel.visible ? false: true
            }
        }
    }

    // Boutons de navigation
    Row {
        id: navigationButtons
        anchors.top: headerSection.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        anchors.topMargin: 4
        height: 30
        spacing: 4

        Button {
            width: (parent.width - parent.spacing) / 2
            height: parent.height

            background: Rectangle {
                color: mapInfoPanel.currentView === 0 ? "#4A90E2" : "#444444"
                radius: 3
                border.color: mapInfoPanel.currentView === 0 ? "#6AB0F2" : "#555555"
                border.width: 1
            }

            contentItem: Row {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🗺️"
                    font.pixelSize: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: "Cartes"
                    color: "white"
                    font.pixelSize: 11
                    font.bold: mapInfoPanel.currentView === 0
                }
            }
            onClicked: {
                mapInfoPanel.currentView = 0
            }
        }

        Button {
            width: (parent.width - parent.spacing) / 2
            height: parent.height

            background: Rectangle {
                color: mapInfoPanel.currentView === 1 ? "#4A90E2" : "#444444"
                radius: 3
                border.color: mapInfoPanel.currentView === 1 ? "#6AB0F2" : "#555555"
                border.width: 1
            }

            contentItem: Row {
                anchors.centerIn: parent
                spacing: 3

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "🖼️"
                    font.pixelSize: 12
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Arrière-plan"
                    horizontalAlignment: Text.AlignHCenter

                    color: "white"
                    font.pixelSize: 11
                    font.bold: mapInfoPanel.currentView === 1
                }
            }

            onClicked: {
                mapInfoPanel.currentView = 1
            }
        }
    }

    // Informations générales de la carte
    Flickable {
        id: mapInfoFlickable
        anchors.top: navigationButtons.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        anchors.topMargin: 6
        height: parent.height - headerSection.height - navigationButtons.height - 16 - 6 - 8 // parent.height - headerSection - navigationButtons - marges
        clip: true
        visible: mapInfoPanel.currentView === 0
        contentHeight: generalInfoColumn.height
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: scrollBar
            active: mapInfoFlickable.contentHeight > mapInfoFlickable.height
            policy: ScrollBar.AlwaysOff
            interactive: true
            anchors.rightMargin: 4
            anchors.topMargin: 3
            anchors.bottomMargin: 3

            contentItem: Rectangle {
                implicitWidth: 6
                radius: width / 2
                color: "#999999"
                opacity: scrollBar.pressed ? 0.8 : 0.5
            }
        }

        Column {
            id: generalInfoColumn
            width: parent.width
            spacing: 6

            Settings {
                id: stEnableAutoSave
                category: "Editor/SaveConfig"
                property var currentMap : value("currentMap", mapInfo.autosaveMapName)
                property var enableAutoSave: value("enableAutoSave", 0)
            }

            // Map Information Container
            Rectangle {
                width: parent.width
                color: "#333333"
                radius: 4
                border.color: "#444444"
                border.width: 1
                height: mapInfoContent.height + 12

                Column {
                    id: mapInfoContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    spacing: 8

                    // Map info header with icon
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: 4

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#4A90E2"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "🗺️"
                                    font.pixelSize: 14
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Map Information"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    // Save button - separate row
                    ParticleButton {
                        id: saveButton
                        width: parent.width
                        height: 30
                        flat: true

                        particleColor: "#32CD32"
                        particleColorVariation: "#00FF00"
                        particleCount: 30
                        particleSize: 6
                        particleLifeSpan: 1500
                        background: Rectangle {
                            anchors.fill: parent
                            color: {
                                if (logic.mapInfo.mapName === mapInfo.autosaveMapName || logic.mapInfo.mapName == ""){
                                    "#5E5A66"
                                }
                                else if (MapFileManager.mapExists(logic.mapInfo.mapName, MapTypes.CUSTOM)){
                                    "#008B8B"
                                }
                                else {
                                    "#4CAF50"
                                }
                            }
                            opacity: 0.8
                            radius: 3
                        }

                        contentItem: Text {
                            text: if (logic.mapInfo.mapName === mapInfo.autosaveMapName || logic.mapInfo.mapName == ""){
                                      "Sauvegarde par défaut"
                                  }
                                  else if (MapFileManager.mapExists(logic.mapInfo.mapName, MapTypes.CUSTOM)){
                                      "Mettre a jour"
                                  }
                                  else {
                                      "Créer une carte"
                                  }
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            font.bold: true
                        }
                        onClicked: {
                            if (typeof logic !== 'undefined' && typeof logic.saveMap === 'function') {
                                var mapInfoLocal = logic.mapInfo
                                logic.saveMap(logic.mapInfo.mapName === mapInfo.autosaveMapName || logic.mapInfo.mapName == "" ? MapTypes.AUTOSAVE : MapTypes.CUSTOM)

                                stEnableAutoSave.setValue("currentMap", mapInfoLocal.mapName)

                            }
                        }
                    }

                    // Grid layout for map details
                    GridLayout {
                        width: parent.width
                        columns: 2
                        columnSpacing: 6
                        rowSpacing: 8

                        // Map name
                        Text {
                            text: "Map Name"
                            color: "#999999"
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 3

                            Row {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Text {
                                    text: "📁"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                }

                                TextField {
                                    id: mapNameInput
                                    width: parent.width - 24
                                    height: parent.height
                                    color: "#4CAF50"
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    placeholderTextColor: "#666666"
                                    placeholderText: text === "" ? "Name of the map" : ""
                                    // text: (logic.mapInfo.mapName === logic.mapInfo.autosaveMapName || logic.mapInfo.mapName === "") ? "" : logic.mapInfo.mapName
                                    Component.onCompleted: text = logic.mapInfo.mapName
                                    onTextChanged: {
                                        logic.mapInfo.mapName = text
                                    }
                                    onEditingFinished: {
                                        logic.saveMap(MapTypes.UNDOREDO)
                                    }
                                }
                            }
                        }

                        // Version
                        Text {
                            text: "Version"
                            color: "#999999"
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 3

                            Row {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4
                                Text {
                                    text: "📈"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                }

                                TextField {
                                    width: parent.width - 24
                                    height: parent.height
                                    color: "white"
                                    font.pixelSize: 12
                                    verticalAlignment: TextInput.AlignVCenter
                                    placeholderTextColor: "#666666"
                                    placeholderText: text === "" ? "1.0" : ""
                                    // text: logic.mapInfo.version.toString()
                                    Component.onCompleted: text = logic.mapInfo.version.toString()
                                    onEditingFinished: {
                                        logic.mapInfo.version = parseInt(text) || 1
                                        logic.saveMap(MapTypes.UNDOREDO)
                                    }
                                }
                            }
                        }

                        // Creation date
                        Text {
                            text: "Created"
                            color: "#999999"
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 3

                            Row {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Text {
                                    text: "📅"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                }

                                TextField {
                                    width: parent.width - 24
                                    height: parent.height
                                    color: "white"
                                    font.pixelSize: 12
                                    placeholderTextColor: "#666666"
                                    placeholderText: text === "" ? "2023-09-15" : ""
                                    // text: logic.mapInfo.mapCreationDate
                                    Component.onCompleted: text = logic.mapInfo.mapCreationDate
                                    onEditingFinished: {
                                        logic.mapInfo.mapCreationDate = text
                                        logic.saveMap(MapTypes.UNDOREDO)
                                    }
                                    verticalAlignment: TextInput.AlignVCenter
                                }
                            }
                        }

                        // Last modification
                        Text {
                            text: "Modified"
                            color: "#999999"
                            font.pixelSize: 12
                            Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            height: 36
                            color: "transparent"
                            border.color: "#4A90E2"
                            border.width: 1
                            radius: 3

                            Row {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 4

                                Text {
                                    text: "🕒"
                                    anchors.verticalCenter: parent.verticalCenter
                                    font.pixelSize: 14
                                }

                                TextField {
                                    width: parent.width - 24
                                    height: parent.height
                                    color: "#4CAF50"
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                    placeholderTextColor: "#666666"
                                    placeholderText: text === "" ? "2023-09-18" : ""
                                    // text: logic.mapInfo.mapLastModified
                                    Component.onCompleted: text = logic.mapInfo.mapLastModified
                                    onEditingFinished: {
                                        logic.mapInfo.mapLastModified = text
                                        logic.saveMap(MapTypes.UNDOREDO)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Description Container
            Rectangle {
                width: parent.width
                color: "#333333"
                radius: 4
                border.color: "#444444"
                border.width: 1
                height: descriptionContent.height + 12

                Column {
                    id: descriptionContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    spacing: 8

                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: 4

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#FFC107"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "📝"
                                    font.pixelSize: 14
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Description"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    // Description text area
                    Rectangle {
                        width: parent.width
                        height: 80
                        color: "transparent"
                        border.color: "#4A90E2"
                        border.width: 1
                        radius: 3

                        Flickable {
                            id: descriptionFlickable
                            anchors.fill: parent
                            anchors.margins: 3
                            contentWidth: descriptionInput.paintedWidth
                            contentHeight: descriptionInput.paintedHeight
                            clip: true

                            TextArea {
                                id: descriptionInput
                                width: descriptionFlickable.width
                                height: Math.max(descriptionFlickable.height, paintedHeight)
                                color: "white"
                                font.pixelSize: 12
                                wrapMode: TextEdit.Wrap
                                placeholderText: text === "" ? "Enter map description here..." : ""
                                // text : logic.mapInfo.mapDescription
                                Component.onCompleted: text = logic.mapInfo.mapDescription
                                placeholderTextColor: "#666666"
                                background: null
                                onEditingFinished: {
                                    logic.mapInfo.mapDescription = text
                                    logic.saveMap(MapTypes.UNDOREDO)
                                }
                            }
                        }

                        // Scrollbar for description
                        ScrollBar {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.rightMargin: 4
                            anchors.topMargin: 3
                            anchors.bottomMargin: 0
                            width: 6
                            policy: ScrollBar.AlwaysOff
                            active: true
                            orientation: Qt.Vertical
                            size: descriptionFlickable.height / descriptionFlickable.contentHeight
                            position: descriptionFlickable.contentY / descriptionFlickable.contentHeight
                            visible: descriptionFlickable.contentHeight > descriptionFlickable.height

                            contentItem: Rectangle {
                                implicitWidth: 6
                                radius: width / 2
                                color: "#999999"
                                opacity: 0.5
                            }
                        }
                    }
                }
            }

            // Statistics Container
            Rectangle {
                width: parent.width
                color: "#333333"
                radius: 4
                border.color: "#444444"
                border.width: 1
                height: statsContent.height + 12

                Column {
                    id: statsContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 6
                    spacing: 8

                    // Stats section header
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: 4

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#E91E63"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "📊"
                                    font.pixelSize: 14
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Statistics"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    // Quick stats in badges
                    Flow {
                        width: parent.width
                        spacing: 5

                        // Stats badges with subtle colors
                        Repeater {
                            model: [
                                {icon: "🔷", label: "Tuiles", value: "42", color: "#673AB7"},
                                {icon: "🏠", label: "Cases", value: "36", color: "#4A90E2"},
                                {icon: "🌳", label: "Déco", value: "6", color: "#FFC107"},
                                {icon: "🎲", label: "Events", value: "12", color: "#E91E63"}
                            ]

                            Rectangle {
                                width: (parent.width - 5) / 2
                                height: 28
                                radius: 14
                                color: Qt.rgba(
                                           parseInt(modelData.color.substr(1, 2), 16) / 255,
                                           parseInt(modelData.color.substr(3, 2), 16) / 255,
                                           parseInt(modelData.color.substr(5, 2), 16) / 255,
                                           0.15
                                           )
                                border.color: modelData.color
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.label + ": " + modelData.value
                                        color: "white"
                                        font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Liste des fonds d'�cran
    // Vue Arrière-plan avec ScrollBar globale
    Flickable {
        id: backgroundFlickable
        anchors.top: navigationButtons.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 8
        anchors.topMargin: 6
        height: parent.height - headerSection.height - navigationButtons.height - 16 - 6 - 8
        clip: true
        visible: mapInfoPanel.currentView === 1
        contentHeight: backgroundColumn.height
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            id: backgroundScrollBar
            policy: ScrollBar.AlwaysOff
            active: backgroundFlickable.contentHeight > backgroundFlickable.height
            interactive: true
            anchors.rightMargin: 4
            anchors.topMargin: 3
            anchors.bottomMargin: 3

            contentItem: Rectangle {
                implicitWidth: 6
                radius: width / 2
                color: "#999999"
                opacity: backgroundScrollBar.pressed ? 0.8 : 0.5
            }
        }

        Column {
            id: backgroundColumn
            width: parent.width
            spacing: 10

            // Contrôles d'affichage
            Rectangle {
                width: parent.width
                height: displayControlsColumn.height + 16
                color: "#333333"
                radius: 4
                border.color: "#444444"
                border.width: 1
                visible: logic.mapInfo.backgroundPath !== ""

                Column {
                    id: displayControlsColumn
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 10

                    Text {
                        text: "Mode d'affichage:"
                        color: "#FFFFFF"
                        font.pixelSize: 12
                        font.bold: true
                    }

                    // Checkbox "Fixé à la grille"
                    CheckBox {
                        id: snapToGridCheckBox
                        text: "Fixé à la grille ?"
                        width: parent.width
                        checked: logic.mapInfo.isBackgroundOnGrill

                        onCheckedChanged: {
                            logic.mapInfo.isBackgroundOnGrill = checked
                            logic.saveMap(MapTypes.UNDOREDO)
                        }

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
                            font.pixelSize: 12
                            color: "#FFFFFF"
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: snapToGridCheckBox.indicator.width + snapToGridCheckBox.spacing
                        }
                    }

                    // Boutons de mode d'affichage
                    Row {
                        width: parent.width
                        height: 36
                        spacing: 6

                        Repeater {
                            model: [
                                {text: "Ajuster", icon: "📐", mode: "Fit"},
                                {text: "Étirer", icon: "↔️", mode: "Stretch"},
                                {text: "Mosaïque", icon: "🔲", mode: "Tile"}
                            ]

                            Rectangle {
                                width: (parent.width - parent.spacing * 2) / 3
                                height: parent.height
                                radius: 4
                                color: logic.mapInfo.backgroundScaling === modelData.mode ? "#4A90E2" : "#3a3a3a"
                                border.color: logic.mapInfo.backgroundScaling === modelData.mode ? "#6AB0F2" : "#555555"
                                border.width: 1

                                Row {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        text: modelData.icon
                                        font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Text {
                                        text: modelData.text
                                        color: "white"
                                        font.pixelSize: 12
                                        font.bold: logic.mapInfo.backgroundScaling === modelData.mode
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        logic.mapInfo.backgroundScaling = modelData.mode
                                        logic.saveMap(MapTypes.UNDOREDO)
                                    }
                                }
                            }
                        }
                    }

                    // Slider pour la taille des tuiles (visible seulement en mode Tile)
                    Column {
                        width: parent.width
                        spacing: 6
                        visible: logic.mapInfo.backgroundScaling === "Tile"

                        Text {
                            text: "Taille des tuiles: " + tileSizeSlider.value + "px"
                            color: "#AAAAAA"
                            font.pixelSize: 11
                        }

                        Slider {
                            id: tileSizeSlider
                            width: parent.width
                            from: 20
                            to: 400
                            stepSize: 20
                            value: logic.mapInfo.backgroundTileSize || 100

                            onValueChanged: {
                                if (typeof logic !== 'undefined' && typeof logic.mapInfo !== 'undefined') {
                                    logic.mapInfo.backgroundTileSize = value
                                }
                            }

                            onPressedChanged: {
                                if (!pressed && typeof logic !== 'undefined') {
                                    logic.saveMap(MapTypes.UNDOREDO)
                                }
                            }

                            background: Rectangle {
                                x: tileSizeSlider.leftPadding
                                y: tileSizeSlider.topPadding + tileSizeSlider.availableHeight / 2 - height / 2
                                width: tileSizeSlider.availableWidth
                                height: 4
                                radius: 2
                                color: "#555555"

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
                                border.width: 1
                            }
                        }
                    }
                }
            }

            // Sélecteur de fond d'écran personnalisé
            Rectangle {
                width: parent.width
                height: customBackgroundContent.height + 16
                color: "#333333"
                radius: 4
                border.color: "#444444"
                border.width: 1

                Column {
                    id: customBackgroundContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 8

                    // Header
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: 4

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#E91E63"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "📷"
                                    font.pixelSize: 14
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Thème personnalisé"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    // Zone de sélection d'image
                    Rectangle {
                        id: customBackgroundSelector
                        width: parent.width
                        height: 100
                        color: "#3a3a3a"
                        radius: 6
                        border.color: imageMouseArea.containsMouse ? "#E91E63" : "#555555"
                        border.width: imageMouseArea.containsMouse ? 2 : 1


                        // Default image icon
                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            visible: mapInfo.backgroundPath === "" || mapInfo.backgroundPath.indexOf("background/") !== -1

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "📷"
                                font.pixelSize: 32
                                color: "#AAAAAA"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Cliquez pour choisir une image"
                                color: "#AAAAAA"
                                font.pixelSize: 12
                                opacity: 0.7
                            }
                        }

                        // Selected image
                        Image {
                            id: selectedCustomImage
                            anchors.fill: parent
                            anchors.margins: 2
                            visible: mapInfo.backgroundPath !== "" && mapInfo.backgroundPath.indexOf("background/") === -1
                            source: mapInfo.backgroundPath
                            fillMode: Image.PreserveAspectCrop

                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: 28
                                color: "#80000000"

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (mapInfo.backgroundPath === "" || mapInfo.backgroundPath.indexOf("background/") === -1) {
                                            return ""
                                        }
                                        var path = mapInfo.backgroundPath.toString()
                                        var fileName = path.substring(path.lastIndexOf("/") + 1)
                                        return fileName.replace(/\.[^/.]+$/, "")
                                    }
                                    color: "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                    width: parent.width - 10
                                    horizontalAlignment: Text.AlignHCenter
                                }
                            }
                        }

                        // Remove image button
                        Rectangle {
                            id: removeButton
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            width: 28
                            height: 28
                            radius: 14
                            color: "#CC2222"
                            visible: mapInfo.backgroundPath !== "" && mapInfo.backgroundPath.indexOf("background/") === -1
                            opacity: removeMouseArea.containsMouse ? 1.0 : 0.8
                            z: 10

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                font.pixelSize: 18
                                font.bold: true
                                color: "white"
                            }

                            MouseArea {
                                id: removeMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    mapInfo.backgroundPath = ""
                                    logic.saveMap(MapTypes.UNDOREDO)
                                }
                            }
                        }

                        MouseArea {
                            id: imageMouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: customFileDialog.open()
                        }
                    }
                }
            }

            // Séparateur
            Rectangle {
                width: parent.width
                height: 30
                color: "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: 10

                    Rectangle {
                        width: 60
                        height: 1
                        color: "#555555"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "OU"
                        color: "#999999"
                        font.pixelSize: 12
                        font.bold: true
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Rectangle {
                        width: 60
                        height: 1
                        color: "#555555"
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // Thèmes par défaut
            Rectangle {
                width: parent.width
                height: defaultBackgroundsContent.height + 16
                color: "#333333"
                radius: 4
                border.color: "#444444"
                border.width: 1

                Column {
                    id: defaultBackgroundsContent
                    width: parent.width - 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 8

                    // Header
                    Rectangle {
                        width: parent.width
                        height: 32
                        color: "#383838"
                        radius: 4

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            spacing: 6

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: "#4A90E2"
                                opacity: 0.2

                                Text {
                                    anchors.centerIn: parent
                                    text: "🖼️"
                                    font.pixelSize: 14
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Thèmes par défaut"
                                color: "white"
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }
                    }

                    // Liste des thèmes
                    Column {
                        width: parent.width
                        spacing: 10

                        Repeater {
                            id: backgroundsList
                            model: AssetManager.getAvailableBackgrounds()

                            Item {
                                width: parent.width
                                height: 90

                                Rectangle {
                                    width: parent.width
                                    height: 90
                                    radius: 6
                                    border.width: mapInfo.backgroundPath === modelData ? 3 : 1
                                    border.color: mapInfo.backgroundPath === modelData ? "#4A90E2" : "#555555"
                                    color: "#3a3a3a"

                                    Image {
                                        id: bgImage
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        source: modelData
                                        fillMode: Image.PreserveAspectCrop

                                        Rectangle {
                                            anchors.bottom: parent.bottom
                                            width: parent.width
                                            height: 28
                                            color: "#80000000"

                                            Text {
                                                anchors.centerIn: parent
                                                text: {
                                                    var fullPath = modelData.toString()
                                                    var fileName = fullPath.substring(fullPath.lastIndexOf('/') + 1)
                                                    return fileName.substring(0, fileName.lastIndexOf('.'))
                                                }
                                                color: "white"
                                                font.pixelSize: 12
                                                font.bold: true
                                                elide: Text.ElideRight
                                                width: parent.width - 10
                                                horizontalAlignment: Text.AlignHCenter
                                            }
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            console.log("Selected background:", modelData)
                                            mapInfo.backgroundPath = modelData
                                            logic.saveMap(MapTypes.UNDOREDO)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
