import QtQuick 2.15
import QtQuick.Controls
import theme
import "."

Item {
    id: resizeHandles
    visible: isSelected && isResizable
    // Assurer que les poignées sont au-dessus de tout

    // Propriétés communes pour les poignées
    property int handleSize: 10
    property color handleColor: Theme.accent
    property color handleBorderColor: "white"
    
    // Poignées aux 8 positions (coins + milieux des côtés)...
    ResizeHandle {
        id: topLeftHandle
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: -parent.handleSize / 2
        direction: "nw"
        gridManager: snapableElement.gridManager
        targetElement: snapableElement
    }
    
    ResizeHandle {
        id: topRightHandle
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: -parent.handleSize / 2
        direction: "ne"
        gridManager: snapableElement.gridManager
        targetElement: snapableElement
    }
    
    ResizeHandle {
        id: bottomLeftHandle
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.margins: -parent.handleSize / 2
        direction: "sw"
        gridManager: snapableElement.gridManager
        targetElement: snapableElement
    }
    
    ResizeHandle {
        id: bottomRightHandle
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: -parent.handleSize / 2
        direction: "se"
        gridManager: snapableElement.gridManager
        targetElement: snapableElement
    }
    
    ResizeHandle {
        id: topHandle
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: -parent.handleSize / 2
        direction: "n"
        gridManager: snapableElement.gridManager
        targetElement: snapableElement
    }
    
    ResizeHandle {
        id: bottomHandle
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: -parent.handleSize / 2
        direction: "s"
        gridManager: snapableElement.gridManager
        targetElement: snapableElement
    }
    
    ResizeHandle {
        id: leftHandle
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: -parent.handleSize / 2
        direction: "w"
        gridManager: snapableElement.gridManager
        targetElement: snapableElement
    }
    
    ResizeHandle {
        id: rightHandle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: -parent.handleSize / 2
        direction: "e"
        gridManager: snapableElement.gridManager
        targetElement: snapableElement
    }
}
