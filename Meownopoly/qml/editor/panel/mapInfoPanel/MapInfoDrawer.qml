import QtQuick
import QtQuick.Controls

Drawer {

    id: mapInfoDrawer
    height: parent.height
    width: Screen.pixelDensity * 75
    edge: Qt.RightEdge

    Rectangle {
        anchors.fill: parent
        color: "#333333"
        radius: 6
        border.color: "#4A90E2"
        border.width: 1
    }

    onPositionChanged: console.log("MapInfoDrawer position changed to: " + position)

    signal refreshPanel()

    onRefreshPanel: {
            console.log("Refreshing Map Side Panel with map name: " + logic.mapInfo.mapName)
            // Les champs Text se mettent à jour automatiquement via les bindings
            // Pas besoin de mise à jour manuelle
    }
}
