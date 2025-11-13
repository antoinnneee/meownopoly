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
import "../../ui_item"
import "../../component"
// import "../component/grid"
// import "../component/preview"
// import "../component/snapable"
import "../panel"
// import "panel/assetSelectionPanel"

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

Item {
    id: panelInfoMap
    property int currentView: 0 // 0 = maps, 1 = background
    x: parent.width

    property bool isOpening: false
    
    required property var logic
    // Conteneur principal
    required property var selectionPanel


    visible: mapsContainer.x < parent.width


    onIsOpeningChanged: {
        if (isOpening) {
            // panelInfoMap.visible = true
            mapsContainer.x = panelInfoMap.width - mapsContainer.width - 10
        } else {
            mapsContainer.x = panelInfoMap.width
        }
    }

    Rectangle {
        id: mapsContainer
        anchors.top: parent.top
        anchors.topMargin: 25
        height: Screen.pixelDensity * 150
        width: Screen.pixelDensity * 75
        color: "#333333"
        radius: 6
        border.color: "#4A90E2"
        border.width: 1
        x: parent.width


        Behavior on x {
            NumberAnimation {
                duration: 500
                easing.type: Easing.InOutQuad
                onFinished: {
                    if (mapsContainer.x >= parent.width) {
                        panelInfoMap.visible = false
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
                        text: panelInfoMap.currentView === 0 ? "🗺️" : "🖼️"
                        font.pixelSize: 10
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panelInfoMap.currentView === 0 ? "Infos carte" : "Fond d'écran"
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

                background: Rectangle {
                    color: parent.hovered ? "#555555" : "transparent"
                    radius: 3
                }

                contentItem: Text {
                    text: "✕"
                    color: "white"
                    font.pixelSize: 12
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    isOpening = false
                    selectionPanel.visible =  selectionPanel.visible ? false: true
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
                    color: panelInfoMap.currentView === 0 ? "#4A90E2" : "#444444"
                    radius: 3
                    border.color: panelInfoMap.currentView === 0 ? "#6AB0F2" : "#555555"
                    border.width: 1
                }

                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🗺️"
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "Cartes"
                        color: "white"
                        font.pixelSize: 9
                        font.bold: panelInfoMap.currentView === 0
                    }
                }
                onClicked: {
                    panelInfoMap.currentView = 0
                }
            }

            Button {
                width: (parent.width - parent.spacing) / 2
                height: parent.height

                background: Rectangle {
                    color: panelInfoMap.currentView === 1 ? "#4A90E2" : "#444444"
                    radius: 3
                    border.color: panelInfoMap.currentView === 1 ? "#6AB0F2" : "#555555"
                    border.width: 1
                }

                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🖼️"
                        font.pixelSize: 10
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Fond"
                        horizontalAlignment: Text.AlignHCenter

                        color: "white"
                        font.pixelSize: 9
                        font.bold: panelInfoMap.currentView === 1
                    }
                }

                onClicked: {
                    panelInfoMap.currentView = 1
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
            visible: panelInfoMap.currentView === 0
            contentHeight: generalInfoColumn.height
            contentWidth: width
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: ScrollBar {
                id: scrollBar
                active: mapInfoFlickable.contentHeight > mapInfoFlickable.height
                policy: ScrollBar.AsNeeded
                visible: mapInfoFlickable.contentHeight > mapInfoFlickable.height
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
                            height: 28
                            color: "#383838"
                            radius: 4

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
                                        text: "🗺️"
                                        font.pixelSize: 10
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Map Information"
                                    color: "white"
                                    font.pixelSize: 10
                                    font.bold: true
                                }
                            }
                        }

                        // Save button - separate row
                        ParticleButton {
                            id: saveButton
                            width: parent.width
                            height: 24
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
                                font.pixelSize: 9
                                font.bold: true
                            }
                            onClicked: {
                                if (typeof logic !== 'undefined' && typeof logic.saveMap === 'function') {
                                    var mapInfoLocal = logic.mapInfo
                                    logic.saveMap(logic.mapInfo.mapName === mapInfo.autosaveMapName || logic.mapInfo.mapName == "" ? MapTypes.AUTOSAVE : MapTypes.CUSTOM)
                                    
                                    stEnableAutoSave.setValue("currentMap", mapInfoLocal.mapName)
                                    
                                    // Rafraîchir la liste des cartes disponibles
                                    leftArrow.availableMaps = MapFileManager.getAvailableMaps()
                                    // Trouver l'index de la nouvelle carte
                                    for (var i = 0; i < leftArrow.availableMaps.length; i++) {
                                        var normalizedName = MapFileManager.findMapFileByName(leftArrow.availableMaps[i])
                                        if (normalizedName === mapInfo.mapName) {
                                            leftArrow.currentIndex = i
                                            break
                                        }
                                    }
                                } else {
                                    console.error("La fonction saveMap n'est pas accessible. Verifiez que la variable 'logic' est definie.")
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
                                font.pixelSize: 9
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
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
                                        font.pixelSize: 10
                                    }

                                    TextField {
                                        width: parent.width - 20
                                        height: parent.height
                                        color: "#4CAF50"
                                        font.pixelSize: 9
                                        verticalAlignment: Text.AlignVCenter
                                        placeholderTextColor: "#666666"
                                        placeholderText: text === "" ? "Name of the map" : ""
                                        text: logic.mapInfo.mapName === logic.mapInfo.autosaveMapName ? "" : logic.mapInfo.mapName
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
                                font.pixelSize: 9
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
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
                                        font.pixelSize: 10
                                    }

                                    TextField {
                                        width: parent.width - 20
                                        height: parent.height
                                        color: "white"
                                        font.pixelSize: 9
                                        verticalAlignment: TextInput.AlignVCenter
                                        placeholderTextColor: "#666666"
                                        placeholderText: text === "" ? "1.0" : ""
                                        text: logic.mapInfo.version.toString()
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
                                font.pixelSize: 9
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
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
                                        font.pixelSize: 10
                                    }

                                    TextField {
                                        width: parent.width - 20
                                        height: parent.height
                                        color: "white"
                                        font.pixelSize: 9
                                        placeholderTextColor: "#666666"
                                        placeholderText: text === "" ? "2023-09-15" : ""
                                        text: logic.mapInfo.mapCreationDate
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
                                font.pixelSize: 9
                                Layout.alignment: Qt.AlignTop | Qt.AlignLeft
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                height: 32
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
                                        font.pixelSize: 10
                                    }

                                    TextField {
                                        width: parent.width - 20
                                        height: parent.height
                                        color: "#4CAF50"
                                        font.pixelSize: 9
                                        verticalAlignment: Text.AlignVCenter
                                        placeholderTextColor: "#666666"
                                        placeholderText: text === "" ? "2023-09-18" : ""
                                        text: logic.mapInfo.mapLastModified
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
                            height: 28
                            color: "#383838"
                            radius: 4

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                spacing: 6

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: "#FFC107"
                                    opacity: 0.2

                                    Text {
                                        anchors.centerIn: parent
                                        text: "📝"
                                        font.pixelSize: 10
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Description"
                                    color: "white"
                                    font.pixelSize: 10
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
                                    font.pixelSize: 9
                                    wrapMode: TextEdit.Wrap
                                    placeholderText: text === "" ? "Enter map description here..." : ""
                                    text : logic.mapInfo.mapDescription
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
                                policy: ScrollBar.AsNeeded
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
                            height: 28
                            color: "#383838"
                            radius: 4

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 6
                                spacing: 6

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: "#E91E63"
                                    opacity: 0.2

                                    Text {
                                        anchors.centerIn: parent
                                        text: "📊"
                                        font.pixelSize: 10
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "Statistics"
                                    color: "white"
                                    font.pixelSize: 10
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
                                    height: 22
                                    radius: 11
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
                                        spacing: 3

                                        Text {
                                            text: modelData.icon
                                            font.pixelSize: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Text {
                                            text: modelData.label + ": " + modelData.value
                                            color: "white"
                                            font.pixelSize: 8
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
        // Sélecteur de fond d'écran personnalisé
        Item {
            id: customBackgroundSelectorContainer
            anchors.top: navigationButtons.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.topMargin: 15
            height: 90
            visible: panelInfoMap.currentView === 1

            Rectangle {
                id: customBackgroundSelector
                width: parent.width - 20
                height: 90
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#3a3a3a"
                radius: 8
                border.color: imageMouseArea.containsMouse ? "#E91E63" : "#555555"
                border.width: imageMouseArea.containsMouse ? 2 : 1

                // Default image icon (shown when no image is selected)
                Column {
                    anchors.centerIn: parent
                    spacing: 5
                    visible: mapInfo.backgroundPath === "" || mapInfo.backgroundPath.indexOf("background/") !== -1

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "📷"
                        font.pixelSize: 24
                        color: "#AAAAAA"
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Thème personnalisé"
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

                    // Caption overlay
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 25
                        color: "#80000000"

                        Text {
                            anchors.centerIn: parent
                            text: {
                                if (mapInfo.backgroundPath === "" || mapInfo.backgroundPath.indexOf("background/") === -1) {
                                    return ""
                                }
                                var path = mapInfo.backgroundPath.toString()
                                var fileName = path.substring(path.lastIndexOf("/") + 1)
                                return fileName.replace(/\.[^/.]+$/, "") // Enlever l'extension
                            }
                            color: "white"
                            font.pixelSize: 11
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
                    anchors.margins: 4
                    width: 24
                    height: 24
                    radius: 12
                    color: "#CC2222"
                    visible: mapInfo.backgroundPath !== "" && mapInfo.backgroundPath.indexOf("background/") === -1
                    opacity: removeMouseArea.containsMouse ? 1.0 : 0.8
                    z: 10

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        font.pixelSize: 16
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

                // Mouse area for image selection
                MouseArea {
                    id: imageMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: customFileDialog.open()
                }
            }
        }

        // Séparateur avec texte
        Rectangle {
            id: separatorWithText
            anchors.top: customBackgroundSelectorContainer.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.topMargin: 15
            height: 30
            color: "transparent"
            visible: panelInfoMap.currentView === 1

            Row {
                anchors.centerIn: parent
                spacing: 10

                Rectangle {
                    width: 50
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
                    width: 50
                    height: 1
                    color: "#555555"
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }

        // Titre pour les fonds d'écran par défaut
        Text {
            id: defaultBackgroundsTitle
            anchors.top: separatorWithText.bottom
            anchors.left: parent.left
            anchors.margins: 10
            anchors.topMargin: 10
            text: "Thèmes par défaut:"
            color: "#FFFFFF"
            font.pixelSize: 14
            font.bold: true
            visible: panelInfoMap.currentView === 1
        }

        // Liste des fonds d'écran par défaut
        ListView {
            id: backgroundsList
            anchors.top: defaultBackgroundsTitle.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.topMargin: 5
            height: Math.max(150, Math.min(contentHeight, parent.height - customBackgroundSelectorContainer.height - separatorWithText.height - defaultBackgroundsTitle.height - 40))
            model: []
            spacing: 10
            clip: true
            focus: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            visible: panelInfoMap.currentView === 1

            ScrollBar.vertical: ScrollBar {
                id: backgroundsScrollBar
                active: backgroundsList.contentHeight > backgroundsList.height
                policy: ScrollBar.AsNeeded
                visible: backgroundsList.contentHeight > backgroundsList.height
                interactive: true
                anchors.rightMargin: 8
                anchors.topMargin: 5
                anchors.bottomMargin: 5

                contentItem: Rectangle {
                    implicitWidth: 8
                    radius: width / 2
                    color: "#999999"
                    opacity: backgroundsScrollBar.pressed ? 0.8 : 0.5
                }
            }

            delegate: Item {
                width: backgroundsList.width
                height: 90

                Rectangle {
                    width: parent.width - 20
                    height: 90
                    anchors.horizontalCenter: parent.horizontalCenter
                    radius: 8
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
                            height: 25
                            color: "#80000000"

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    var fullPath = modelData.toString()
                                    var fileName = fullPath.substring(fullPath.lastIndexOf('/') + 1)
                                    return fileName.substring(0, fileName.lastIndexOf('.'))
                                }
                                color: "white"
                                font.pixelSize: 11
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
                            panelInfoMap.visible = false
                        }

                        onEntered: {
                        }

                        onExited: {
                        }
                    }
                }
            }
        }
    }

    // Flèche gauche pour navigation de cartes
    Rectangle {
        id: leftArrow
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 20
        anchors.bottomMargin: 20
        width: 50
        height: 50
        radius: 25
        color: "#4A90E2"
        border.color: "#6AB0F2"
        border.width: 2
        z: 9000
        visible: parent.visible

        property var availableMaps: []
        property int currentIndex: -1

        Text {
            anchors.centerIn: parent
            text: "◀"
            font.pixelSize: 24
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                parent.color = "#6AB0F2"
            }

            onExited: {
                parent.color = "#4A90E2"
            }

            onClicked: {
                if (leftArrow.availableMaps.length === 0) return

                leftArrow.currentIndex--
                if (leftArrow.currentIndex < 0) {
                    leftArrow.currentIndex = leftArrow.availableMaps.length - 1
                }

                var selectedMap = leftArrow.availableMaps[leftArrow.currentIndex]
                logic.removeCurrentMap()
                var normalizedMapName = MapFileManager.findMapFileByName(selectedMap)
                if (normalizedMapName !== "") {
                    Game.loadMap(normalizedMapName, MapTypes.CUSTOM)
                    mapInfo.mapName = normalizedMapName
                    stEnableAutoSave.setValue("currentMap", normalizedMapName)
                }
            }
        }
    }

    // Nom de la carte courante au centre
    Rectangle {
        id: currentMapName
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: Math.max(200, mapNameText.contentWidth + 40)
        height: 50
        radius: 8
        color: "#333333"
        border.color: "#4A90E2"
        border.width: 2
        z: 9000
        visible: parent.visible

        Text {
            id: mapNameText
            anchors.centerIn: parent
            text: mapInfo.mapName === mapInfo.autosaveMapName ? "Autosave" : mapInfo.mapName
            font.pixelSize: 16
            font.bold: true
            color: "white"
        }
    }

    // Flèche droite pour navigation de cartes
    Rectangle {
        id: rightArrow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        width: 50
        height: 50
        radius: 25
        color: "#4A90E2"
        border.color: "#6AB0F2"
        border.width: 2
        z: 9000
        visible: parent.visible

        Text {
            anchors.centerIn: parent
            text: "▶"
            font.pixelSize: 24
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: {
                parent.color = "#6AB0F2"
            }

            onExited: {
                parent.color = "#4A90E2"
            }

            onClicked: {
                if (leftArrow.availableMaps.length === 0) return

                leftArrow.currentIndex++
                if (leftArrow.currentIndex >= leftArrow.availableMaps.length) {
                    leftArrow.currentIndex = 0
                }

                var selectedMap = leftArrow.availableMaps[leftArrow.currentIndex]
                logic.removeCurrentMap()
                var normalizedMapName = MapFileManager.findMapFileByName(selectedMap)
                if (normalizedMapName !== "") {
                    Game.loadMap(normalizedMapName, MapTypes.CUSTOM)
                    mapInfo.mapName = normalizedMapName
                    stEnableAutoSave.setValue("currentMap", normalizedMapName)
                }
            }
        }
    }

    // FileDialog pour la sélection d'image personnalisée
    FileDialog {
        id: customFileDialog
        title: "Sélectionner une image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]
        onAccepted: {
            mapInfo.backgroundPath = customFileDialog.selectedFile
            logic.saveMap(MapTypes.UNDOREDO)
        }
    }

    onVisibleChanged: {
        if (visible) {
            backgroundsList.model = AssetManager.getAvailableBackgrounds()

            // Initialiser la liste des maps et l'index courant
            leftArrow.availableMaps = MapFileManager.getAvailableMaps()
            // Trouver l'index de la carte courante
            for (var i = 0; i < leftArrow.availableMaps.length; i++) {
                var normalizedName = MapFileManager.findMapFileByName(leftArrow.availableMaps[i])
                if (normalizedName === mapInfo.mapName) {
                    leftArrow.currentIndex = i
                    break
                }
            }
        }
    }
}
