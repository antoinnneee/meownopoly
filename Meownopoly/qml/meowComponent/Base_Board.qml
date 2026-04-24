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

    // Level 2 — `mapInfo` est désormais un *alias dynamique* vers le MapInfo
    // de Map::currentMap côté C++, pas une copie locale. Conséquences :
    //  - Toute mutation d'UI (ex. `mapInfo.backgroundPath = x`) écrit
    //    directement sur le MapInfo de la Map active → plus aucune
    //    divergence entre l'état UI et ce que saveCurrentMap sérialise.
    //  - La fonction QML `setMapInfo(info)` d'antan disparaît : la
    //    synchro post-loadMap se fait automatiquement via la ré-évaluation
    //    du binding sur `MapFileManager.currentMap.mapInfo`.
    //
    // Fallback : au tout début de l'app (avant le premier Game.loadMap)
    // currentMap peut être null. On renvoie alors une instance vide
    // `_fallbackMapInfo` pour éviter les déréférencements null dans les
    // lecteurs (Background.qml, panels, etc.). Les mutations sur le
    // fallback sont volatiles (pas persistées) — ne devraient pas arriver
    // en pratique puisque l'UI qui écrit n'est montée qu'après init.
    MapInfo {
        id: _fallbackMapInfo
    }

    readonly property MapInfo mapInfo: (MapFileManager.currentMap
                                         && MapFileManager.currentMap.mapInfo)
                                        ? MapFileManager.currentMap.mapInfo
                                        : _fallbackMapInfo

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
