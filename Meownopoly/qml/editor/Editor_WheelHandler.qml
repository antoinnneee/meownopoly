import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import Game
import Case
import ItemSnapable
import "../component"
import "../component/grid"
import "../component/snapable"
import "panel"
import "panel/caseSelectionPanel"
import "panel/assetSelectionPanel"
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
                 for (var i = 0; i < logic.snapableTilesList.length; i++) {
                     if (logic.snapableTilesList[i]) {
                         logic.snapableTilesList[i].isSelected = false
                         logic.snapableTilesList[i].snapToGridFromGridPos()
                     }
                 }
                 
             }
}
