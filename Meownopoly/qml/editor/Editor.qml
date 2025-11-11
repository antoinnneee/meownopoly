import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore
import Case
import ItemSnapable
import "../component"
import "../component/grid"
import "../component/preview"
import "../component/snapable"
import "panel"
import "panel/assetSelectionPanel"

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
import "../ui_item"

Rectangle {
    id: root

    color: "lightblue"
    border.width: 0
    focus: true
    property int appPositionX: 0
    property int appPositionY: 0
    property int availableHeight: height - selectionPanel.height


    property real z_CONFIG_PANEL: 10000
    property real z_HUD: 9000
    property real z_SELECTION_RECT: 8000
    property real z_CURSOR_TRACKER: 7000
    property real z_LINK_TRACKER: 6000




    property MapInfo mapInfo: MapInfo{
        mapName: autosaveMapName
    }

    // Liste pour stocker tous les SnapableCaseTile créés
    property alias snapableTilesList: logic.snapableTilesList

    // Asset selection properties
    property alias isAssetSelected: selectionPanel.isAssetSelected

    property alias escMenu:escMenu

    signal updateSettings()
    property alias entity:entity

    Component.onCompleted: {
        stEnableAutoSave.sync()
        initializeEditor()
    }

    onUpdateSettings: {
        console.log("Update setting - stEnableAutoSave.value('saveEvent', '0') " + stEnableAutoSave.value('saveEvent', "1"))
        tmpSaver.interval =  stEnableAutoSave.value("saveEvent", "1") === 2 ? stEnableAutoSave.value("saveInterval", "0") * 1000 * 60: 500
        tmpSaver.running = stEnableAutoSave.value("saveEvent", "1") === 1 ? false : true
    }

    Keys.onPressed: function(event) {
        console.log("event", event.key)
        if (event.key === Qt.Key_Delete) {
            var selectItem = logic.mouseLogic.selectedElements
            if (selectItem.length === 0) {
                event.accepted = true
                return
            }

            // Attendre que toutes les animations de suppression soient terminées avant de sauvegarder
            var pendingDeletions = selectItem.length

            // Handler appelé quand chaque animation de suppression est terminée
            var deletionHandler = function() {
                pendingDeletions--
                if (pendingDeletions === 0) {
                    // Toutes les animations sont terminées, sauvegarder maintenant
                    logic.saveMap(MapTypes.UNDOREDO)
                }
            }

            // Connecter au signal elementDeleted de chaque élément et déclencher la suppression
            for (var i = 0; i < selectItem.length; i++) {
                var element = selectItem[i]
                element.elementDeleted.connect(deletionHandler)
                element.deleteRequest(false)
            }
            event.accepted = true
        }
        else if (event.key === Qt.Key_Escape) {
            if (root.isAssetSelected) {
                selectionPanel.clearAssetSelection()
                event.accepted = true
            } else if (logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK) {
                logic.mouseLogic.unSelectSelectedElements()
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
                event.accepted = true
            } else {
                // Afficher le menu d'échappement
                escMenu.show()
                event.accepted = true
            }
        }
        else if (event.key === Qt.Key_Control) {
            logic.mouseLogic.isControlPressed = true
        }
        else if (event.key === Qt.Key_Y) {
            if (logic.mouseLogic.isControlPressed)
                console.log("Redo requested via Ctrl+Y")
            Game.askNext()
        }
        else if (event.key === Qt.Key_Z) {
            if (logic.mouseLogic.isControlPressed)
                console.log("Undo requested via Ctrl+Z")
            Game.askPreview()
        }
        else if (event.key === 178)
        {
            adminCommandPanel.visible = !adminCommandPanel.visible
        }
    }
    Keys.onReleased:{
        logic.mouseLogic.isControlPressed = false
    }

    AnimatedImage {
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        z: z_HUD
        id: aIGlobalSettings
        // text: "⚙️"
        fillMode: Image.PreserveAspectFit
        source: AssetManager.getAssetPath("ui", "hud", "0")
        width: 16
        height: 16
        // font.pointSize: 12
        MouseArea {
            anchors.fill:  parent
            onClicked: {
                console.log("onClicked Opening global settings")
                panelInfoMap.visible = !panelInfoMap.visible
                selectionPanel.visible = false
            }
        }
    }
    Item {
        id: panelInfoMap
        anchors.fill: parent
        z: root.z_CONFIG_PANEL
        visible: false
        
        property int currentView: 0 // 0 = maps, 1 = background
        
        // Conteneur principal
        Rectangle {
            id: mapsContainer
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 50
            anchors.rightMargin: 10
            width: Screen.pixelDensity * 120
            height: headerSection.height + navigationButtons.height + contentHeight + 30
            color: "#333333"
            radius: 6
            border.color: "#4A90E2"
            border.width: 1
            
            property int contentHeight: panelInfoMap.currentView === 0 
                ? (mapsList.visible ? Math.max(200, Math.min(mapsList.contentHeight + 20, Screen.pixelDensity * 100)) : 140)
                : Math.max(200, Math.min(backgroundsList.contentHeight + 20, Screen.pixelDensity * 100))
            
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

                        // background: Rectangle {
                        //     anchors.fill: parent
                        //     color: parent.hovered ? "#555555" : "#444444"
                        //     radius: 4
                        //     border.color: "#4A90E2"
                        //     border.width: 1
                        // }

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
            
            // Message "Aucune carte enregistrée" quand la liste est vide
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
            
            // Liste des fonds d'écran
            ListView {
                id: backgroundsList
                anchors.top: navigationButtons.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                height: Math.max(200, Math.min(contentHeight, Screen.pixelDensity * 100))
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
        
        // Rafraîchir la liste quand le panneau devient visible
        onVisibleChanged: {
            if (visible) {
                mapsList.model = MapFileManager.getAvailableMaps()
                backgroundsList.model = AssetManager.getAvailableBackgrounds()
            }
        }
    }

    // Flèche gauche pour navigation de cartes
    Rectangle {
        id: leftArrow
        anchors.left: parent.left
        anchors.bottom: selectionPanel.top
        anchors.leftMargin: 20
        anchors.bottomMargin: 20
        width: 50
        height: 50
        radius: 25
        color: "#4A90E2"
        border.color: "#6AB0F2"
        border.width: 2
        z: root.z_HUD
        visible: panelInfoMap.visible
        
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
        anchors.bottom: selectionPanel.top
        anchors.bottomMargin: 20
        width: Math.max(200, mapNameText.contentWidth + 40)
        height: 50
        radius: 8
        color: "#333333"
        border.color: "#4A90E2"
        border.width: 2
        z: root.z_HUD
        visible: panelInfoMap.visible
        
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
        anchors.bottom: selectionPanel.top
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        width: 50
        height: 50
        radius: 25
        color: "#4A90E2"
        border.color: "#6AB0F2"
        border.width: 2
        z: root.z_HUD
        visible: panelInfoMap.visible
        
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
    
    // Connexion pour initialiser la liste des maps et l'index courant
    Connections {
        target: panelInfoMap
        function onVisibleChanged() {
            if (panelInfoMap.visible) {
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

    AdminCommandPanel{
        id: adminCommandPanel
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 10
        visible: false
        enabled: visible

        height: Screen.pixelDensity * 100
        z: z_CONFIG_PANEL
    }

    Settings {
        id: stEnableAutoSave
        category: "Editor/SaveConfig"
        property var currentMap : value("currentMap", mapInfo.autosaveMapName)
        property int saveEvent: value("saveEvent", "1")
    }

    Timer {
        id: tmpSaver
        repeat: true
        interval : stEnableAutoSave.value("saveEvent", "1") === 2 ? stEnableAutoSave.value("saveInterval", "0") * 1000 * 60 : 500
        running: stEnableAutoSave.value("saveEvent", "1") === 1 ? false : true
        property bool isMapCustom : mapInfo.mapName !== mapInfo.autosaveMapName
        onTriggered: {
            console.log("Auto-saving map:", mapInfo.mapName)
            if (isMapCustom)
                logic.saveMap(MapTypes.CUSTOM)
            else
                logic.saveMap(MapTypes.AUTOSAVE)

            busyTimer.start()
        }
    }

    Timer {
        id: busyTimer
        interval: 1500
        repeat: false
        running: false
        triggeredOnStart: true
        onTriggered: {
            stEnableAutoSave.saveEvent === 2 ? (savingIndicator.running = savingIndicator.running ? false : true) : null
        }
    }

    BusyIndicator {
        id: savingIndicator
        z: z_HUD
        anchors.right: parent.right
        anchors.top: parent.top
        width: Screen.pixelDensity * 10
        height: width
        running: false
    }

    Connections {
        target: UndoRedoManager
        function onForceUnSelectAllElement() {
            logic.mouseLogic.unselectSelectedElements()
        }
    }
    Connections{
        target: Game

        function onFoundItemSnapableTile(itemSnapableData){
            Logger.info("Found itemSnapableData tile:" + itemSnapableData, "MAP_LOADING")
            logic.tileLogic.createItemSnapable(itemSnapableData);
        }

        function onMapLoaded(map)
        {
            Logger.success("Map loaded", "MAP_LOADING")
            logic.tileLogic.builtConnections();

            // Copy properties from loaded map to preserve bindings
            if (map.mapInfo) {
                mapInfo.mapName = map.mapInfo.mapName
                mapInfo.mapDescription = map.mapInfo.mapDescription
                mapInfo.mapCreationDate = map.mapInfo.mapCreationDate
                mapInfo.mapLastModified = map.mapInfo.mapLastModified
                mapInfo.version = map.mapInfo.version
                mapInfo.backgroundPath = map.mapInfo.backgroundPath
                mapInfo.backgroundScaling = map.mapInfo.backgroundScaling
                mapInfo.backgroundTileSize = map.mapInfo.backgroundTileSize
                mapInfo.isBackgroundOnGrill = map.mapInfo.isBackgroundOnGrill
                mapInfo.musicPath = map.mapInfo.musicPath
            }

            if (mapInfo.mapName !== stEnableAutoSave.currentMap)
                stEnableAutoSave.setValue("currentMap", mapInfo.mapName)

            // Check if we're restoring from undo/redo
            if (UndoRedoManager.isRestoringState) {
                console.log("[UNDO][RESTORE] Map loaded during restoration - NOT saving")
                // Clear the restoration flag now that loading is complete
                UndoRedoManager.clearRestorationFlag()
            } else {
                // Only save initial state if not restoring
                console.log("[UNDO][SAVE] Map loaded normally - saving initial state")
                logic.saveMap(MapTypes.UNDOREDO)
            }
        }

        function onClearCurrentMap() {
            logic.removeCurrentMap()
        }
    }

    Editor_WheelHandler { }

    EditorLogic {
        id: logic
        workArea: workArea
        editorGrid: editorGrid
        selectionRect:  selectionRect
        mapInfo: root.mapInfo
        selectionPanel: selectionPanel
    }

    // Grille de l'éditeur
    GridManager {
        id: editorGrid
        mmSize: logic.mmSize
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
    }

    Background {
        id: background
        grid: editorGrid
        anchors.fill: mapInfo.isBackgroundOnGrill ? editorGrid : parent
    }

    GlobalMa {
        id: mainMa
        mouseLogic: logic.mouseLogic
        anchors.bottom: selectionPanel.top
    }
    // Zone de travail de l'éditeur (par-dessus la grille)
    Item {
        id: workArea
        anchors.fill: editorGrid
        Item {
            id: groupeSelection
            property int gridXPosition:  0
            property int gridYPosition:  0
        }

        Rectangle{
            id: entity
            color: "purple"
            width: 50
            height: 50
            radius: width
            z: 1000
            visible: false
            Behavior on x  { SmoothedAnimation { velocity: 350 } }
            Behavior on y { SmoothedAnimation { velocity: 350 } }
        }


        // MouseArea to track cursor position for asset preview
        MouseArea {
            id: cursorTracker
            anchors.fill: parent
            hoverEnabled: true
            enabled: logic.editorMouseMode === EditorEnum.EM_POSE
            acceptedButtons: Qt.NoButton // Don't interfere with clicks
            propagateComposedEvents: true
            preventStealing: true
            z: 50

            onPositionChanged: function(mouse) {
                assetPreview.mouseX = mouse.x
                assetPreview.mouseY = mouse.y
            }
        }


        // MouseArea to track cursor position for link preview
        MouseArea {
            id: linkTracker
            z: z_LINK_TRACKER
            anchors.fill: parent
            hoverEnabled: true
            enabled: logic.editorMouseMode === EditorEnum.EM_SELECTION_LINK
            acceptedButtons: Qt.NoButton // Don't interfere with clicks
            propagateComposedEvents: true
            preventStealing: true


            onPositionChanged: function(mouse) {
                if (logic.mouseLogic && logic.mouseLogic.updateMousePosition) {
                    logic.mouseLogic.updateMousePosition(mouse.x, mouse.y)
                }
            }
        }

        // Asset preview cursor
        AssetPreviewCursor {
            id: assetPreview
            parent: workArea
            assetCategory: selectionPanel.currentSelectedAssetCategory
            assetType: selectionPanel.currentSelectedAssetType
            assetId: selectionPanel.currentSelectedAssetId
            caseType: selectionPanel.caseTypeSelected
            isCasePreview: selectionPanel.caseTypeSelected !== -1
            unitSizeWidth: logic.tileLogic.currentElementWidth
            unitSizeHeight: logic.tileLogic.currentElementHeight
            gridManager: editorGrid
            selectionPanel: selectionPanel
        }
    }

    InteractiveUiElement{
        z: z_HUD
        x:10
        y:10
        width: Screen.pixelDensity * 30
        height: Screen.pixelDensity * 30
        contentItem : Player_Profil_Icon{
            decorationParameter.decorationCategory: "ui"
            decorationParameter.decorationType: "cat"
            decorationParameter.decorationId: ""
            anchors.fill: parent
        }
    }


    // Rectangle de sélection
    SelectionRect {
        id: selectionRect
        z: z_SELECTION_RECT
    }

    SelectionPanel{
        id: selectionPanel

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        // anchors.right: parent.right
        anchors.right: sidePanel.left

        z: z_HUD


        // Connexion à la logique
        logic: logic

        // Définir la valeur d'expansion par défaut
        isExpanded: true

        onIsSidePanelExpandedChanged: {
            console.log("SelectionPanel: Side panel expanded state changed to", isSidePanelExpanded, " x ", sidePanel.x)
            if (isSidePanelExpanded) {
                sidePanel.x = parent.width - sidePanel.width
            } else {
                sidePanel.x = parent.width
            }
        }


        onIsExpandedChanged: {
            console.log("SelectionPanel: Side panel expanded state changed to", isSidePanelExpanded, " x ", sidePanel.x)
            if (isExpanded) {
                sidePanel.height = Qt.binding(function() {
                    return selectionPanel.height
                })
            } else {
                sidePanel.height = 0
            }
        }

        //Connect the selected decoration element for effects
        Timer {
            id: saveMapTimer
            interval: 100
            onTriggered: {
                logic.saveMap(MapTypes.UNDOREDO)
            }
        }

        onAssetSelected: function(category, type, id) {
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
        }
        onAssetCleared: function() {
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }
        onEffectChanged: {
            var effects = selectionPanel.assetPanel.visualEffectsPanel.getCurrentEffects()
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                logic.mouseLogic.selectedElements[i].applyVisualEffects(effects)
            }
            if (saveMapTimer.running)
                saveMapTimer.restart()
            else
                saveMapTimer.start()
        }
        onCaseTypeSelectedChanged: {
            if (selectionPanel.caseTypeSelected !== -1)
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_POSE)
            else
                logic.mouseLogic.changeMouseMode(EditorEnum.EM_NORMAL)
        }
        onConnectionRequested:  function (kind) {
            var targetElement = selectionPanel.connectionsPanel.targetSnapableElement

            /* save selected element to reasign it */
            var selectedElements = []
            for (var i = 0; i < logic.mouseLogic.selectedElements.length; i++) {
                selectedElements.push(logic.mouseLogic.selectedElements[i])
            }
            console.log("onConnectionRequested", kind, selectedElements)
            logic.mouseLogic.changeMouseMode(EditorEnum.EM_SELECTION_LINK)
            logic.mouseLogic.kind = kind
            logic.mouseLogic.setSelectedElementList(selectedElements)
            logic.mouseLogic.linkSourceCase = targetElement


            // Afficher la prévisualisation du lien
            if (logic.mouseLogic && logic.mouseLogic.showLinkPreview) {
                logic.mouseLogic.showLinkPreview()
            }
        }
    }

    EditorSidePanel {
        id: sidePanel
        z: z_HUD
        anchors.bottom: parent.bottom
        x: parent.width
    }

    MenuMapAtStart {
        z: z_CONFIG_PANEL
        onBackgroundSelected: function() {
        }
    }

    // Menu d'échappement
    EditorEscMenu {
        id: escMenu
        z: z_CONFIG_PANEL
        onVisibleChanged: {
            console.log("EscMenu visibility changed:", visible)
            if (!visible) {
                // Redonner le focus à l'éditeur quand le menu se ferme
                root.forceActiveFocus()
            }
        }
        onIndexSaveEvent: {
            stEnableAutoSave.sync()
            root.updateSettings()
        }
    }

    function regainFocus() {
        forceActiveFocus()
    }

    function initializeEditor() {
        if (!MapFileManager.mapExists(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)){
            console.log("Creating autosave map")
            MapFileManager.createMapFile("", MapTypes.AUTOSAVE)
            logic.saveMap(MapTypes.AUTOSAVE)
        }
        else {
            console.log("Autosave map already exists")
        }
        if (stEnableAutoSave.currentMap !== mapInfo.autosaveMapName) {
            console.log("Loading custom map:", stEnableAutoSave.currentMap)
            if (MapFileManager.mapExists(stEnableAutoSave.currentMap, MapTypes.CUSTOM)){
                Game.loadMap(stEnableAutoSave.currentMap, MapTypes.CUSTOM)
                mapInfo.mapName = stEnableAutoSave.currentMap
            }
            else {
                stEnableAutoSave.setValue("currentMap", mapInfo.autosaveMapName)
                mapInfo.mapName = mapInfo.autosaveMapName
                Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
            }
        }
        else  {
            console.log("Loading autosave map")
            Game.loadMap(mapInfo.autosaveMapName, MapTypes.AUTOSAVE)
        }
        if (stEnableAutoSave.value("saveEvent", "1") !== 1) {
            tmpSaver.start()
        }
    }

    // Function to place the selected asset
    function placeSelectedAsset(gridX, gridY) {
        var snapableParameters
        gridX = gridX - Math.trunc(logic.tileLogic.currentElementWidth/2)
        gridY = gridY - Math.trunc(logic.tileLogic.currentElementHeight/2)
        if (!root.isAssetSelected) {    // place case
            if (selectionPanel.caseTypeSelected == -1){ //no type selected
                return
            }
            snapableParameters = ItemSnapableFactory.createItemSnapable(selectionPanel.caseTypeSelected)
        }
        else    // place decoration
        {
            snapableParameters = ItemSnapableFactory.createItemSnapable()
        }
        snapableParameters.displayParameter.gridRelativePositionX = gridX
        snapableParameters.displayParameter.gridRelativePositionY = gridY
        snapableParameters.displayParameter.unitSizeWidth = logic.tileLogic.currentElementWidth
        snapableParameters.displayParameter.unitSizeHeight = logic.tileLogic.currentElementHeight
        snapableParameters.displayParameter.zLayer = 5
        snapableParameters.decorationParameter.decorationCategory = selectionPanel.currentSelectedAssetCategory
        snapableParameters.decorationParameter.decorationType = selectionPanel.currentSelectedAssetType
        snapableParameters.decorationParameter.decorationId = selectionPanel.currentSelectedAssetId

        var newTile = logic.tileLogic.createItemSnapable(snapableParameters)

        var visualEffectsPanel = selectionPanel.assetPanel.visualEffectsPanel
        if (!visualEffectsPanel || !visualEffectsPanel.effectsLocked) return

        var currentEffects = visualEffectsPanel.getCurrentEffects()
        newTile.applyVisualEffects(currentEffects)
        mainMa.elementClicked(newTile)
    }

    Component.onDestruction: {
        if (logic.mouseLogic && logic.mouseLogic.hideLinkPreview) {
            logic.mouseLogic.hideLinkPreview()
        }
    }

}

