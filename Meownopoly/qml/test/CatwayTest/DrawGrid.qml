import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0

Item {
    id: gridRoot
    property var host: null
    property var targetPlayer: null

    property string paintColor: "#7c3aed"

    property int gridRows: 16
    property int gridCols: 64
    property int cellPixels: 10
    property int gridWidth: gridCols * cellPixels
    property int gridHeight: gridRows * cellPixels

    width: gridWidth
    height: gridHeight

    ListModel {
        id: gridModel
        Component.onCompleted: {
            for (var i = 0; i < gridRows * gridCols; i++)
                gridModel.append({ "cellColor": "" })
        }
    }

    function clearLocal() {
        for (var i = 0; i < gridModel.count; i++)
            gridModel.setProperty(i, "cellColor", "")
    }

    function clearAll() {
        clearLocal()
    }

    function setCellColor(idx, colorStr) {
        if (idx >= 0 && idx < gridModel.count) {
            gridModel.setProperty(idx, "cellColor", colorStr)
        }
    }

    function cellIndexAt(mx, my) {
        var col = Math.floor(mx / cellPixels)
        var row = Math.floor(my / cellPixels)
        if (col < 0 || col >= gridCols || row < 0 || row >= gridRows)
            return -1
        return row * gridCols + col
    }

    function setCellAt(mx, my, paint) {
        var idx = cellIndexAt(mx, my)
        if (idx >= 0) {
            var colorStr = paint ? String(paintColor) : ""
            if (gridModel.get(idx).cellColor !== colorStr) {
                gridModel.setProperty(idx, "cellColor", colorStr)
                if (gridRoot.targetPlayer) {
                    Catway.sendReliableToPlayer(gridRoot.targetPlayer, "DRAW:" + idx + ":" + colorStr)
                }
            }
        }
    }

    Grid {
        id: grid
        rows: gridRows
        columns: gridCols
        spacing: 1
        anchors.fill: parent

        Repeater {
            model: gridModel
            delegate: Rectangle {
                width: cellPixels - 1
                height: cellPixels - 1
                color: model.cellColor || "#222226"
                radius: 1
                border.width: 0
            }
        }
    }

    MouseArea {
        id: gridMouseArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        preventStealing: true

        property bool paintMode: true

        onPressed: function(mouse) {
            paintMode = (mouse.button === Qt.LeftButton)
            setCellAt(mouse.x, mouse.y, paintMode)
        }
        onPositionChanged: function(mouse) {
            if (pressed)
                setCellAt(mouse.x, mouse.y, paintMode)
        }
    }
}
