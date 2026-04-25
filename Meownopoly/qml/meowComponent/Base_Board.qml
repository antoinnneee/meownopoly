import QtQuick 2.15
import UiStyle
import MapInfo
import MapFileManager
import meowComponent

Rectangle {
    id: board


    property Base_logic logic
    onLogicChanged: {
        console.log("logic changed")
    }

    // Level 2 — `mapInfo` pointe vers le MapInfo de Map::currentMap côté C++.
    // Toute mutation d'UI (ex. `mapInfo.backgroundPath = x`) écrit directement
    // sur le MapInfo actif → plus de divergence avec ce que saveCurrentMap
    // sérialise.
    //
    // Implémentation : initialement un binding déclaratif
    // `readonly property MapInfo mapInfo: currentMap ? currentMap.mapInfo : _fallback`.
    // Ça déclenchait un *binding loop* de QML (symptôme : "Binding loop
    // detected for property mapInfo" + une cascade de "TypeError: Cannot read
    // property 'X' of null" sur tous les lecteurs). Cause profonde : la
    // double-indirection `currentMap.mapInfo` combinée au re-ciblage de
    // `mapInfoChanged` quand currentMap change rend le binding instable ;
    // QML stoppe l'évaluation → la propriété reste à null → tous les lecteurs
    // déréfèrencent null.
    //
    // Solution imperative : la propriété est initialisée au fallback ; on la
    // met à jour via Connections sur les deux signaux qui peuvent affecter
    // la valeur (currentMapChanged et mapInfoChanged de la Map en cours).
    // Garde contre les re-entrée avec `!==`.
    MapInfo {
        id: _fallbackMapInfo
    }

    property MapInfo mapInfo: _fallbackMapInfo

    function _syncMapInfo() {
        var cMap = MapFileManager.currentMap
        var next = (cMap && cMap.mapInfo) ? cMap.mapInfo : _fallbackMapInfo
        if (board.mapInfo !== next) board.mapInfo = next
    }

    Component.onCompleted: _syncMapInfo()

    Connections {
        target: MapFileManager
        function onCurrentMapChanged() { _syncMapInfo() }
    }

    // target: binding live — se ré-évalue quand currentMap change et
    // attache onMapInfoChanged au nouveau Map. ignoreUnknownSignals tolère
    // le cas currentMap === null (signal introuvable, ignoré silencieusement).
    Connections {
        target: MapFileManager.currentMap
        ignoreUnknownSignals: true
        function onMapInfoChanged() { _syncMapInfo() }
    }

    property WheelHandler wheelHandler


    property alias gameGrid:gameGrid
    GridManager {
        id: gameGrid
        gridColor: "#80000000"
        gridOpacity: 0.3
        showGrid: true
        snapToGrid: true
        z: UiStyle.z_GRID
    }

    property alias background:background
    Background {
        id: background
        grid: gameGrid
        anchors.fill: mapInfo.isBackgroundOnGrill ? gameGrid : parent
        z: UiStyle.z_BACKGROUND
    }

    property alias mainMa: mainMa
    GlobalMa {
        id: mainMa
        mouseLogic: logic.mouseLogic
        anchors.fill: parent
        z: UiStyle.z_GLOBAL_MA
        Component.onCompleted: drag.target = gameGrid
    }
}
