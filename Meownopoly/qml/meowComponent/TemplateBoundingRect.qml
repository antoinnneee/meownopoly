import QtQuick 2.15
import theme

/**
 * Rectangle vert pour afficher la bounding box des éléments sélectionnés en mode template.
 * Utilisé par le Repeater dans Trackers.qml pour afficher un ou plusieurs rectangles.
 */
Item {
    id: templateBoundingRect
    
    // Données de la bounding box (x, y, width, height passés via modelData)
    property var boundingData: null
    
    // Propriétés calculées depuis boundingData
    x: boundingData ? boundingData.x : 0
    y: boundingData ? boundingData.y : 0
    width: boundingData ? boundingData.width : 0
    height: boundingData ? boundingData.height : 0
    
    visible: boundingData !== null && width > 0 && height > 0
    z: 100
    
    // Fond semi-transparent vert
    Rectangle {
        id: backgroundFill
        anchors.fill: parent
        color: Theme.success
        opacity: 0.15
        radius: Theme.radiusS
    }

    // Bordure verte avec effet de brillance
    Rectangle {
        id: borderOuter
        anchors.fill: parent
        color: "transparent"
        radius: Theme.radiusS
        border.color: "#81C784"  // Vert clair
        border.width: 3
    }

    Rectangle {
        id: borderInner
        anchors.fill: parent
        anchors.margins: 2
        color: "transparent"
        radius: Theme.radiusXS
        border.color: Theme.success  // Vert principal
        border.width: 2
    }
    
    // Coins décoratifs (optionnel, pour un effet plus visuel)
    Repeater {
        model: [
            {ax: "left", ay: "top"},
            {ax: "right", ay: "top"},
            {ax: "left", ay: "bottom"},
            {ax: "right", ay: "bottom"}
        ]
        
        Rectangle {
            width: 12
            height: 12
            color: Theme.success
            radius: Theme.radiusXS
            
            x: modelData.ax === "left" ? -2 : parent.width - width + 2
            y: modelData.ay === "top" ? -2 : parent.height - height + 2
        }
    }
    
    // Animation subtile de pulsation sur la bordure
    SequentialAnimation on opacity {
        running: templateBoundingRect.visible
        loops: Animation.Infinite
        NumberAnimation { to: 0.85; duration: 1000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
    }
}
