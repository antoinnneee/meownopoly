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
import "../../ui_item"
import "../../component"
import "../panel"

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

Item {
    id: infoMapPanel
    property int currentView: 0 // 0 = maps, 1 = background
    x: parent.width

    property bool isOpening: false

    required property var logic
    // Conteneur principal
    required property var selectionPanel
    required property var sidePanel

    visible: mapSidePanel.x < parent.width


    onIsOpeningChanged: {
        if (isOpening) {
            // infoMapPanel.visible = true
            mapSidePanel.x = infoMapPanel.width - mapSidePanel.width - 10
        } else {
            mapSidePanel.x = infoMapPanel.width
        }
    }

    MapSidePanel {
        id: mapSidePanel
        property alias infoMapPanel: infoMapPanel
    }

    // Barre de navigation des cartes
    MapNavigationBar {
        id: mapNavigationBar
    }

    onVisibleChanged: {
        if (visible) {
            mapNavigationBar.isVisible()
        }
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
