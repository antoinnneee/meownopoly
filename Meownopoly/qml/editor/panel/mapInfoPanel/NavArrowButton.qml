import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQml
import QtCore

import Game
import MapFileManager
import MapTypes
import MapInfo

// Barre de navigation des cartes - Version refactoris�e
Rectangle {
    id: navButton
    width: 50
    height: 50
    radius: 25
    z: 9000
    visible: !selectionPanel.visible
    // enabled: mapNavigationBar.availableMaps.length > 0
    enabled : !MapFileManager.isCustomAutosaveMap()
    property string arrowText: ""
    property bool isLeft: true
    signal clicked()
    
    // Gradient de base
    gradient: Gradient {
        orientation: Gradient.Vertical
        GradientStop { 
            position: 0.0
            color: navButtonMa.containsMouse ? "#7dd3fc" : "#4A90E2"
        }
        GradientStop { 
            position: 1.0
            color: navButtonMa.containsMouse ? "#38bdf8" : "#2563eb"
        }
    }
    
    border.color: navButtonMa.containsMouse ? "#0ea5e9" : "#6AB0F2"
    border.width: 2
    
    Text {
        anchors.centerIn: parent
        text: navButton.arrowText
        font.pixelSize: 24
        color: "white"
    }
    
    MouseArea {
        id: navButtonMa
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        enabled: mapNavigationBar.availableMaps.length > 0
        hoverEnabled: enabled
        onClicked: navButton.clicked()
    }
    
    // Animation de scale au hover
    scale: navButtonMa.containsMouse ? 1.1 : 1.0
    Behavior on scale {
        NumberAnimation { duration: 150; easing.type: Easing.OutBack }
    }
}
