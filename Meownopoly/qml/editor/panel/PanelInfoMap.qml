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

    property bool isOpen: false
    // Conteneur principal

    onIsOpenChanged: {
        if (isOpen) {
            panelInfoMap.visible = true
            mapsContainer.x = panelInfoMap.width - mapsContainer.width - 10
        } else {
            mapsContainer.x = panelInfoMap.width
        }
    }


    Rectangle {
        id: mapsContainer
        // anchors.right: parent.right
        // anchors.rightMargin: 10
        anchors.top: parent.top
        anchors.topMargin: 50
        width: Screen.pixelDensity * 120
        // height: headerSection.height + navigationButtons.height + contentHeight + 30
        height: Screen.pixelDensity * 165
        color: "#333333"
        radius: 6
        border.color: "#4A90E2"
        border.width: 1
        x: parent.width
        property int contentHeight: panelInfoMap.currentView === 0
                                    ? (mapsList.visible ? Math.max(200, Math.min(mapsList.contentHeight + 20, Screen.pixelDensity * 100)) : 140)
                                    : (customBackgroundSelectorContainer.height + separatorWithText.height + defaultBackgroundsTitle.height + Math.max(150, Math.min(backgroundsList.contentHeight + 20, Screen.pixelDensity * 60)))
        
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
            width: parent.width*0.8
            height: 40
            color: "#383838"
            radius: 6
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter

            Row {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.leftMargin: 10
                spacing: 10

                Rectangle {
                    width: 30
                    height: 30
                    radius: 15
                    color: "#4A90E2"
                    opacity: 0.2

                    Text {
                        anchors.centerIn: parent
                        text: panelInfoMap.currentView === 0 ? "🗺️" : "🖼️"
                        font.pixelSize: 16
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panelInfoMap.currentView === 0 ? "Load a map" : "Choose background"
                    color: "white"
                    font.pixelSize: 14
                    font.bold: true
                }
            }

            // Bouton fermer
            Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.rightMargin: 10
                width: 30
                height: 30

                background: Rectangle {
                    color: parent.hovered ? "#555555" : "transparent"
                    radius: 4
                }

                contentItem: Text {
                    text: "✕"
                    color: "white"
                    font.pixelSize: 16
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                onClicked: {
                    panelInfoMap.visible = false
                }
            }
        }

        // Boutons de navigation
        Row {
            id: navigationButtons
            anchors.top: headerSection.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.topMargin: 5
            height: 40
            spacing: 5

            Button {
                width: (parent.width - parent.spacing) / 2
                height: parent.height

                background: Rectangle {
                    color: panelInfoMap.currentView === 0 ? "#4A90E2" : "#444444"
                    radius: 4
                    border.color: panelInfoMap.currentView === 0 ? "#6AB0F2" : "#555555"
                    border.width: 1
                }

                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🗺️"
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: "Cartes"
                        color: "white"
                        font.pixelSize: 13
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
                    radius: 4
                    border.color: panelInfoMap.currentView === 1 ? "#6AB0F2" : "#555555"
                    border.width: 1
                }

                contentItem: Row {
                    anchors.centerIn: parent
                    spacing: 5

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "🖼️"
                        font.pixelSize: 14
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Fond d'écran"
                        horizontalAlignment: Text.AlignHCenter

                        color: "white"
                        font.pixelSize: 13
                        font.bold: panelInfoMap.currentView === 1
                    }
                }

                onClicked: {
                    panelInfoMap.currentView = 1
                }
            }
        }

        // Liste des maps
        ListView {
            id: mapsList
            anchors.top: navigationButtons.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            height: Math.max(200, Math.min(contentHeight, Screen.pixelDensity * 100))
            model: []
            spacing: 5
            clip: true
            focus: true
            interactive: true
            boundsBehavior: Flickable.StopAtBounds
            visible: panelInfoMap.currentView === 0 && model.length > 0

            ScrollBar.vertical: ScrollBar {
                id: scrollBar
                active: mapsList.contentHeight > mapsList.height
                policy: ScrollBar.AsNeeded
                visible: mapsList.contentHeight > mapsList.height
                interactive: true
                anchors.rightMargin: 8
                anchors.topMargin: 5
                anchors.bottomMargin: 5

                contentItem: Rectangle {
                    implicitWidth: 8
                    radius: width / 2
                    color: "#999999"
                    opacity: scrollBar.pressed ? 0.8 : 0.5
                }
            }

            delegate: Item {
                width: mapsList.width
                height: 40

                Button {
                    width: parent.width - 20
                    height: 40
                    anchors.horizontalCenter: parent.horizontalCenter

                    background: Rectangle {
                        anchors.fill: parent
                        color: parent.hovered ? "#555555" : "#444444"
                        radius: 4
                        border.color: "#4A90E2"
                        border.width: 1
                    }

                    contentItem: Text {
                        text: modelData
                        font.pixelSize: 16
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    onClicked: {
                        console.log("Selected map: " + modelData)
                        logic.removeCurrentMap()
                        var normalizedMapName = MapFileManager.findMapFileByName(modelData)
                        if (normalizedMapName !== "") {
                            Game.loadMap(normalizedMapName, MapTypes.CUSTOM)
                            mapInfo.mapName = normalizedMapName
                            stEnableAutoSave.setValue("currentMap", normalizedMapName)
                            panelInfoMap.visible = false
                        } else {
                            console.error("Could not find map file for: " + modelData)
                        }
                    }
                }
            }
        }

        // Message "Aucune carte enregistr�e" quand la liste est vide
        Rectangle {
            id: emptyStateMessage
            anchors.top: navigationButtons.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 10
            anchors.topMargin: 20
            height: 100
            visible: panelInfoMap.currentView === 0 && mapsList.model.length === 0

            color: "#3a3a3a"
            radius: 8
            border.color: "#555555"
            border.width: 1

            Column {
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "📂"
                    font.pixelSize: 32
                    opacity: 0.5
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Aucune carte enregistrée"
                    color: "#999999"
                    font.pixelSize: 14
                    font.italic: true
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
            height: Math.max(150, Math.min(contentHeight, Screen.pixelDensity * 60))
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
            mapsList.model = MapFileManager.getAvailableMaps()
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
