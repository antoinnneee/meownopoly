pragma ComponentBehavior:Bound

import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

Rectangle {
    id: root
    
    // Propriétés configurables
    property var action: null
    onActionChanged: console.log(action.icon)
    property int padSize: 60
    property color padColor: "#FFB6C1"
    property color hoverColor: Qt.lighter(padColor, 1.2)
    property color pressedColor: Qt.darker(padColor, 1.2)
    
    // Signal
    signal clicked()
    
    // Dimensions
    width: padSize
    height: padSize
    radius: width / 2
    
    // Couleur avec états
    color: mouseArea.pressed ? pressedColor : 
           mouseArea.containsMouse ? hoverColor : padColor
    
    // Bordure
    border.color: Qt.darker(color, 1.3)
    border.width: 1
    
    // Effet d'ombre
    layer.enabled: true
    layer.effect: DropShadow {
        horizontalOffset: 2
        verticalOffset: 2
        radius: 4.0
        samples: 9
        color: "#30000000"
        transparentBorder: true
    }
    
    // Contenu du bouton
    Item {
        anchors.centerIn: parent
        width: parent.width * 0.7
        height: parent.height * 0.7
        
        // Icône si disponible
        Image {
            id: actionIcon
            anchors.centerIn: parent
            width: parent.width
            height: parent.height
            source: (action && action.icon) ? action.icon : ""
            fillMode: Image.PreserveAspectFit
            visible: source != ""
            smooth: true
        }
        
        // Texte de fallback si pas d'icône
        Text {
            anchors.centerIn: parent
            text: (action && action.label && actionIcon.source == "") ? 
                  action.label.charAt(0).toUpperCase() : ""
            font.pixelSize: parent.height * 0.5
            font.bold: true
            color: "white"
            visible: actionIcon.source == "" && text != ""
        }
        
        // Indicateur si l'action est désactivée
        Rectangle {
            anchors.fill: parent
            radius: parent.width / 2
            color: "#80000000"
            visible: action && action.enabled === false
            
            Text {
                anchors.centerIn: parent
                text: "✕"
                color: "white"
                font.pixelSize: parent.height * 0.3
            }
        }
    }
    
    // Zone de clic
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: !action || action.enabled !== false
        
        onClicked: {
            root.clicked()
        }
    }
    
    // Animation de clic
    Behavior on scale {
        NumberAnimation { duration: 100 }
    }
    
    // Animation au survol
    states: [
        State {
            name: "pressed"
            when: mouseArea.pressed
            PropertyChanges { target: root; scale: 0.9 }
        },
        State {
            name: "hovered"
            when: mouseArea.containsMouse && !mouseArea.pressed
            PropertyChanges { target: root; scale: 1.1 }
        }
    ]
    
    transitions: [
        Transition {
            NumberAnimation { properties: "scale"; duration: 100; easing.type: Easing.OutQuad }
        }
    ]
    
    // Tooltip pour afficher le nom de l'action
    ToolTip {
        visible: mouseArea.containsMouse && action && action.label
        text: action ? action.label : ""
        delay: 500
    }
}
