import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import Game
import Case
import ItemSnapable
import "tools"
import "tools/snapable"
import "panel"
import "panel/caseConfigPanel"
import "panel/assetSelectionPanel"
import MapLoader
import MapInfo
import EditorEnum

WheelHandler {
    onWheel: (wheel)=> {
                 if (wheel.angleDelta.y > 0)
                 {
                     logic.scrollLogic.scrollUp(wheel)
                 }
                 else if (wheel.angleDelta.y < 0)
                 {
                     logic.scrollLogic.scrollDown(wheel)
                 }
                 if (wheel.angleDelta.x > 0)
                 {
                     logic.scrollLogic.scrollRight(wheel)
                 }
                 else if (wheel.angleDelta.x < 0)
                 {
                     logic.scrollLogic.scrollLeft(wheel)
                 }
                 for (var i = 0; i < root.snapableTilesList.length; i++) {
                     if (root.snapableTilesList[i]) {
                         root.snapableTilesList[i].isSelected = false
                         root.snapableTilesList[i].snapToGridFromGridPos()
                     }
                 }
                 
             }
}
