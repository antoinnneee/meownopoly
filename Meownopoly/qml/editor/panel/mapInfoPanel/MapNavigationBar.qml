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
import "../../../ui_item"
import "../../../component"
import "../../panel"

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


// Barre de navigation des cartes
Item {
    id: mapNavigationBar
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom

    signal isVisible()
    signal refeshListMap()

    onRefeshListMap: {
        leftArrow.availableMaps = MapFileManager.getAvailableMaps()
        findCurrentMap()
    }

    onIsVisible: {
        if (isVisible)
            findCurrentMap()
    }

    function findCurrentMap(){
        // Trouver l'index de la carte courante
        for (var i = 0; i < leftArrow.availableMaps.length; i++) {
            var normalizedName = MapFileManager.findMapFileByName(leftArrow.availableMaps[i])
            if (normalizedName === mapInfo.mapName) {
                leftArrow.currentIndex = i
                break
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
        visible: selectionPanel.visible ? false : true

        property var availableMaps: MapFileManager.getAvailableMaps()
        property int currentIndex: -1

        Text {
            anchors.centerIn: parent
            text: "◀"
            font.pixelSize: 24
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: leftArrow.availableMaps.length > 0
            hoverEnabled: enabled

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

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        anchors.rightMargin: width/2
        spacing: 10

        // Nom de la carte courante au centre & suppresion de la carte 🗑️
        Rectangle {
            id: currentMapName
            height: 50
            radius: 0
            color: "#333333"
            z: 9000
            visible: selectionPanel.visible ? false : true
            Component.onCompleted:{
                width = Math.max(200, mapNameText.contentWidth + 40)
                console.log("From parent currentMapName width = ", width)
                console.log("From parent mapNameText width = ", mapNameText.width)

            }
            signal mapNameSet()
            onMapNameSet: width = Math.max(200, mapNameText.contentWidth + 40)

            Text {
                id: mapNameText
                anchors.centerIn: parent
                text: (mapInfo.mapName === mapInfo.autosaveMapName || mapInfo.mapName === "") ? "Autosave" : mapInfo.mapName
                onTextChanged: currentMapName.mapNameSet()
                font.pixelSize: 16
                font.bold: true
                color: "white"
                Component.onCompleted: {
                    currentMapName.mapNameSet()
                    console.log("From child currentMapName width = ", currentMapName.width)
                    console.log("From child mapNameText width = ", mapNameText.width)

                }
            }
        }

        Button {
            id: mapSupprBt
            width: mapSupprText.contentWidth
            height: mapSupprText.contentHeight
            z: 9000
            visible: selectionPanel.visible ? false : true
            enabled: mapInfo.mapName !== "Autosave" && mapInfo.mapName !== ""
            hoverEnabled: enabled
            onHoveredChanged: {
                if (mapSupprBt.scale === 1.1){
                    mapSupprBt.scale = 1.0
                    confirmationStep = 0
                }
                else
                    mapSupprBt.scale = 1.1
            }
            property int confirmationStep: 0
            onClicked: {
                confirmationStep += 1
                if (confirmationStep >= 2) {
                    console.log("Deleting map:", mapInfo.mapName)
                    logic.deleteMap(mapInfo.mapName)
                    logic.removeCurrentMap()
                    confirmationStep = 0

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
                    refeshListMap()
                }
            }
            Text {
                id: mapSupprText
                text: mapSupprBt.confirmationStep == 0 ? "🗑️" : "🗑️? "
                font.pointSize: 28
                font.bold: true
                color: "black"
            }
            background: Rectangle {
                id: bkRectSupprMap
                anchors.fill : mapSupprBt
                radius: 8
                color: "#CC2222"
                border.color: "black"
                border.width: 1.4
            }

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
        visible: selectionPanel.visible ? false : true

        Text {
            anchors.centerIn: parent
            text: "▶"
            font.pixelSize: 24
            color: "white"
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: leftArrow.availableMaps.length > 0
            hoverEnabled: enabled

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
}
