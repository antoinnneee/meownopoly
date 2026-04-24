import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml
import QtCore

import Game
import MapFileManager
import MapTypes
import MapInfo

// Barre de navigation des cartes - Version refactorisée
Item {
    id: mapNavigationBar

    // Properties
    property var availableMaps: []
    property int currentIndex: 0
    property string currentMapName: ""
    property bool isCurrentMapAutosave: false


    signal keyArrowPressed()

    // Settings pour persister le nom du dernier .json custom ouvert.
    Settings {
        id: mapSettings
        category: "Editor/SaveConfig"
        property string lastOpenedMap: value("lastOpenedMap", mapInfo.autosaveMapName)
    }

    // Signals
    signal mapListRefreshed()

    Component.onCompleted: {
        refreshMapList()
    }

    // === CORE FUNCTIONS ===

    function refreshMapList() {
        availableMaps = MapFileManager.getAvailableMaps()
        syncCurrentIndex()
        mapListRefreshed()
    }

    function syncCurrentIndex() {
        if (availableMaps.length === 0) {
            currentIndex = -1
            return
        }

        // Trouver l'index de la carte actuellement chargée
        for (var i = 0; i < availableMaps.length; i++) {
            var mapDisplayName = availableMaps[i]
            var normalizedName = MapFileManager.findMapFileByName(mapDisplayName)

            if (normalizedName === mapInfo.mapName) {
                currentIndex = i
                updateCurrentMapInfo()
                return
            }
        }

        // Si la carte courante n'est pas trouvée, sélectionner la première
        currentIndex = 0
        updateCurrentMapInfo()
    }

    function updateCurrentMapInfo() {
        if (currentIndex >= 0 && currentIndex < availableMaps.length) {
            var mapDisplayName = availableMaps[currentIndex]
            currentMapName = MapFileManager.findMapFileByName(mapDisplayName)
            isCurrentMapAutosave = MapFileManager.isAutosaveMap(currentMapName)
            // stEnableAutoSave.setValue(currentMapName)
        }
    }

    function navigateToMap(index) {
        if (availableMaps.length === 0) return

        // Wrap around
        if (index < 0) {
            index = availableMaps.length - 1
        } else if (index >= availableMaps.length) {
            index = 0
        }

        currentIndex = index
        var mapDisplayName = availableMaps[currentIndex]
        var normalizedName = MapFileManager.findMapFileByName(mapDisplayName)

        if (normalizedName === "") {
            console.warn("Map not found:", mapDisplayName)
            return
        }

        // Déterminer le type de carte
        var mapType = MapFileManager.getMapType(normalizedName)

        // Level 4 — Game.loadMap émet clearCurrentMap en entrée ; plus
        // besoin d'appeler logic.removeCurrentMap() manuellement.
        Game.loadMap(normalizedName, mapType)
        mapInfo.mapName = normalizedName
        mapSettings.setValue("lastOpenedMap", normalizedName)

        updateCurrentMapInfo()
        keyArrowPressed()
    }

    function navigatePrevious() {
        navigateToMap(currentIndex - 1)
    }

    function navigateNext() {
        navigateToMap(currentIndex + 1)
    }

    function deleteCurrentMap() {
        if (availableMaps.length === 0) return
        if (currentIndex < 0 || currentIndex >= availableMaps.length) return

        var mapToDelete = currentMapName
        var indexToDelete = currentIndex

        console.log("Deleting map:", mapToDelete)

        // Supprimer la carte
        logic.deleteMap(mapToDelete)
        // Level 4 — le wipe des tuiles QML arrive via Game.loadMap ci-dessous
        // (navigateToMap ou fallback autosave) qui émet clearCurrentMap.

        // Rafraîchir la liste AVANT de naviguer
        refreshMapList()

        // Naviguer vers la carte suivante (ou précédente si c'était la dernière)
        if (availableMaps.length > 0) {
            // Ajuster l'index si nécessaire
            var newIndex = indexToDelete
            if (newIndex >= availableMaps.length) {
                newIndex = availableMaps.length - 1
            }
            navigateToMap(newIndex)
        } else {
            // Level 1d : plus aucune carte → retomber sur l'autosave.
            // Sans ce fallback, MapFileManager.currentMap pointait encore
            // sur la Map dont le fichier venait d'être supprimé ; toute
            // save-on-mod ultérieure recréait silencieusement le fichier.
            console.log("MapNavigationBar: plus de cartes, fallback autosave")
            if (!MapFileManager.mapExists(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)) {
                MapFileManager.createMapFile("", MapTypes.AUTOSAVE)
            }
            Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
            mapInfo.mapName = mapInfo.autosaveMapName
            refreshMapList()
        }
    }

    // === UI COMPONENTS ===

    // Style commun pour les boutons de navigation
    component NavArrowButton: Rectangle {
        id: navButton
        width: 50
        height: 50
        radius: 25
        z: 9000
        // visible: !selectionPanel.visible

        property string arrowText: ""
        property bool isLeft: true
        signal clicked()

        // Gradient de base
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop {
                position: 0.0
                color: navButtonMa.containsMouse ? "#7dd3fc" : "#4A90E2"
            }
            GradientStop {
                position: 1.0
                color: navButtonMa.containsMouse ? "#38bdf8" : "#2563eb"
            }
        }

        border.color: navButtonMa.containsMouse ? "#0ea5e9" : "#6AB0F2"
        border.width: 2

        Text {
            anchors.centerIn: parent
            text: navButton.arrowText
            font.pixelSize: 24
            color: "white"
        }

        MouseArea {
            id: navButtonMa
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: mapNavigationBar.availableMaps.length > 0
            hoverEnabled: enabled
            onClicked: navButton.clicked()
        }

        // Animation de scale au hover
        scale: navButtonMa.containsMouse ? 1.1 : 1.0
        Behavior on scale {
            NumberAnimation { duration: 150; easing.type: Easing.OutBack }
        }
    }

    // Flèche gauche
    NavArrowButton {
        id: leftArrow
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 20
        anchors.bottomMargin: 20
        arrowText: "◀"
        isLeft: true
        onClicked: {
            mapNavigationBar.navigatePrevious()
            keyArrowPressed()
        }
    }

    // Zone centrale avec nom de carte et bouton de suppression
    Row {
        id: centerRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        spacing: 10
        z: 9000
        // visible: !selectionPanel.visible

        // Affichage du nom de la carte
        Rectangle {
            id: mapNameContainer
            width: Math.max(200, mapNameText.contentWidth + 40)
            height: 50
            radius: 8
            z: 9000

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: "#1e293b" }
                GradientStop { position: 0.5; color: "#334155" }
                GradientStop { position: 1.0; color: "#1e293b" }
            }

            border.color: isCurrentMapAutosave ? "#f59e0b" : "#64748b"
            border.width: 1

            Row {
                anchors.centerIn: parent
                spacing: 8

                // Indicateur autosave
                Rectangle {
                    visible: isCurrentMapAutosave
                    width: 8
                    height: 8
                    radius: 4
                    color: "#f59e0b"
                    anchors.verticalCenter: parent.verticalCenter

                    SequentialAnimation on opacity {
                        running: isCurrentMapAutosave
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 800 }
                        NumberAnimation { to: 1.0; duration: 800 }
                    }
                }

                Text {
                    id: mapNameText
                    text: {
                        if (mapInfo.mapName === "" || mapInfo.mapName === mapInfo.autosaveMapName) {
                            return "Autosave"
                        }
                        return mapInfo.mapName
                    }
                    font.pixelSize: 16
                    font.bold: true
                    color: "white"
                }
            }
            // Indicateur de position dans la liste
            Text {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: 4
                text: availableMaps.length > 0 ? (currentIndex + 1) + "/" + availableMaps.length : "0/0"
                font.pixelSize: 10
                color: "#94a3b8"
            }
        }

        // Bouton de suppression
        Button {
            id: deleteButton
            width: 50
            height: 50
            z: 9000
            enabled: !isCurrentMapAutosave && mapInfo.mapName !== ""
            visible: enabled

            property int confirmationStep: 0

            onHoveredChanged: {
                if (!hovered) {
                    confirmationStep = 0
                }
            }

            onClicked: {
                confirmationStep++
                if (confirmationStep >= 2) {
                    mapNavigationBar.deleteCurrentMap()
                    confirmationStep = 0
                }
                keyArrowPressed()
            }

            contentItem: Text {
                text: deleteButton.confirmationStep === 0 ? "🗑️" : "❓"
                font.pixelSize: 24
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            background: Rectangle {
                radius: 8

                gradient: Gradient {
                    orientation: Gradient.Vertical
                    GradientStop {
                        position: 0.0
                        color: deleteButton.confirmationStep > 0 ? "#ef4444" :
                                                                   deleteButton.hovered ? "#f87171" : "#dc2626"
                    }
                    GradientStop {
                        position: 1.0
                        color: deleteButton.confirmationStep > 0 ? "#b91c1c" :
                                                                   deleteButton.hovered ? "#ef4444" : "#991b1b"
                    }
                }

                border.color: deleteButton.confirmationStep > 0 ? "#fca5a5" : "#f87171"
                border.width: deleteButton.confirmationStep > 0 ? 2 : 1

                // Animation pulsation lors de la confirmation
                SequentialAnimation on scale {
                    running: deleteButton.confirmationStep > 0
                    loops: Animation.Infinite
                    NumberAnimation { to: 1.05; duration: 300 }
                    NumberAnimation { to: 1.0; duration: 300 }
                }
            }

            scale: hovered ? 1.1 : 1.0
            Behavior on scale {
                NumberAnimation { duration: 150; easing.type: Easing.OutBack }
            }
        }
    }

    // Flèche droite
    NavArrowButton {
        id: rightArrow
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        arrowText: "▶"
        isLeft: false
        onClicked:{
            mapNavigationBar.navigateNext()
            keyArrowPressed()
        }
    }

    // Refresh auto à chaque changement de Map active.
    // Ancienne version écoutait parent.onVisibleChanged, mais MapInfoPanel
    // (le parent) n'est jamais masqué/ré-affiché : le signal ne fire jamais.
    //
    // currentMapChanged de MapFileManager est émis par setCurrentMap, donc
    // couvre tous les chemins de "la carte active a changé" :
    //   - initial load (Editor.qml:initializeEditor)
    //   - navigation via flèches (navigateToMap → Game.loadMap)
    //   - création nouvelle carte (MenuMapAtStart.onNewMapSet → Game.loadMap)
    //   - load depuis EscMenu
    //   - fallback autosave après delete (Level 1d)
    //   - FullSync collab qui swap la Map
    //
    // refreshMapList() re-lit le disque + re-synchronise currentIndex contre
    // mapInfo.mapName courant (binding Level 2 live). Résout le bug
    // "counter affiche 3/3 au lieu de 4/4 après création" + "flèches ne
    // peuvent atteindre la nouvelle carte".
    Connections {
        target: MapFileManager
        function onCurrentMapChanged() {
            mapNavigationBar.refreshMapList()
        }
    }
}