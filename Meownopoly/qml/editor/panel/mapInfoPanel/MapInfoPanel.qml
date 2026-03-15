import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Shapes
import QtQml
import QtCore
import QtQuick.Dialogs
import Case
import ItemSnapable
import ui_item
import "../../../meowComponent"

import Game
import MapFileManager
import MapTypes
import MapInfo
import EditorEnum
import Logger
import DisplayParameter
import DecorationParameter
import ItemSnapableFactory
import AssetManager

Item {
    id: mapInfoPanel
    property int currentView: 0 // 0 = maps, 1 = background
    x: parent.width

    property bool isOpening: false

    required property var logic
    // Conteneur principal
    required property var selectionPanel
    required property var sidePanel

    property alias mapInfoDrawer: mapInfoDrawer
    signal openDrawer()
    onOpenDrawer: mapInfoDrawer.open()

    MapInfoDrawer {
        id: mapInfoDrawer
        property alias mapInfoPanel: mapInfoPanel
        property bool selPanelOriginalState : false
        onOpened:{
            selectionPanel.visible =  false
            selPanelOriginalState = selectionPanel.isExpanded
        }
        onClosed:{
            selectionPanel.visible =  true
            selectionPanel.isExpanded = selPanelOriginalState
        }
    }

    // Barre de navigation des cartes
    MapNavigationBar {
        id: mapNavigationBar
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: mapInfoDrawer.position === 0 ? 0 : mapInfoDrawer.width + 5
        anchors.bottom: parent.bottom
        visible: mapInfoDrawer.position === 1
        z: mapInfoDrawer+1
        onKeyArrowPressed: mapInfoDrawer.open()
    }

    // FileDialog pour la sélection d'image personnalisée
    FileDialog {
        id: customFileDialog
        title: "Sélectionner une image"
        nameFilters: ["Image files (*.png *.jpg *.jpeg *.gif *.bmp)"]
        onAccepted: {
            mapInfo.backgroundPath = customFileDialog.selectedFile
            logic.saveMap(MapTypes.UNDOREDO)
        }
    }
}
