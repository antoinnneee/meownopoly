import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore

import UiStyle

import Case
import ItemSnapable

import meowComponent


import Game
import MapFileManager
import MapTypes
import MapInfo
import EditorEnum
import Logger
import DisplayParameter
import DecorationParameter
import AssetManager
import ItemSnapableFactory
import ui_item

import utils
import chat

import QtQuick3D
import QtQuick3D.Helpers

import editor
import theme
import "."

Image {
    id: btSideMenu
    z: UiStyle.z_HUD
    source: AssetManager.getAssetById("ui", "hud", "0").path
    width: Screen.pixelDensity * 20
    height: Screen.pixelDensity * 20
    
    property string colorBt : "transparent"
    property string emojiBt : ""

    signal btClicked()

    Rectangle {
        anchors.fill: parent
        color: colorBt
        opacity: 0.4
        radius: width/2
    }
    
    Text {
        text: emojiBt
        anchors.centerIn: parent
        font.pixelSize: Theme.fontSizeHeading
    }
    
    MouseArea {
        hoverEnabled: true
        anchors.fill:  parent
        onClicked: {
            btSideMenu.btClicked()
        }
    }    
    // SequentialAnimation {
    //     id: btInfoMapAnim
    //     running: false
    //     SmoothedAnimation {velocity: 0.9; to: 1.2; target: btInfoMap; property: "scale"; easing.type: Easing.InOutQuad }
    //     SmoothedAnimation {velocity: 1.1; to: 1; target: btInfoMap; property: "scale"; easing.type: Easing.InOutQuad }
    // }
}
