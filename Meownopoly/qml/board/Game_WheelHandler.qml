import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Window
import QtQuick.Shapes
import QtQuick.Layouts
import QtQml


import Logger
import Game
import Case
import MapTypes
import MapFileManager
import MapInfo
import EditorEnum
import DisplayParameter
import DecorationParameter
import ItemSnapable
import "logic"
import "../component"
import "../component/snapable"
import "../component/grid"

WheelHandler {
    onWheel: (wheel) => {
                 if (wheel.angleDelta.y > 0) {
                     logic.scrollLogic.scrollUp(wheel)
                 }
                 else if (wheel.angleDelta.y < 0) {
                     logic.scrollLogic.scrollDown(wheel)
                 }
                 if (wheel.angleDelta.x > 0) {
                     logic.scrollLogic.scrollRight(wheel)
                 }
                 else if (wheel.angleDelta.x < 0) {
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
