pragma ComponentBehavior:Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Rectangle {
    id: mainPad

    property color mainColor: "#FFA7B6"
    property color hoverColor: "#FF8A9B"
    property color pressedColor: "#FF6B82"

    // État du menu
    property bool isOpen: false
    property int mainPadSize: 120

    property string menuName: mainPad.isOpen ? "✕" : "🐾"

    signal menuToggled(var toogle)

    width: mainPadSize
    height: mainPadSize
    radius: width / 2


    color: mainPadMouseArea.pressed ? pressedColor :
                                      mainPadMouseArea.containsMouse ? hoverColor : mainColor
    
    // Bordure subtile
    border.color: Qt.darker(color, 1.2)
    border.width: 2
    
    // Effet d'ombre
    layer.effect: DropShadow {
        horizontalOffset: 3
        verticalOffset: 3
        radius: 8.0
        samples: 17
        color: "#40000000"
        transparentBorder: true
    }
    
    // Icône ou texte au centre
    Text {
        anchors.centerIn: parent
        text: mainPad.menuName
        font.pixelSize: mainPad.mainPadSize * 0.3
        color: "white"
        font.bold: true
    }
    
    // Animation de pulsation
    SequentialAnimation on scale {
        running: !mainPad.isOpen
        loops: Animation.Infinite
        NumberAnimation { to: 1.05; duration: 1000; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
    }
    
    // Zone de clic
    MouseArea {
        id: mainPadMouseArea
        anchors.fill: parent
        hoverEnabled: true
        
        onClicked: {
            mainPad.isOpen = !mainPad.isOpen
            menuToggled(mainPad.isOpen)
        }
    }
    
    // Animation de clic
    Behavior on scale {
        NumberAnimation { duration: 100 }
    }
    /*
    layer: {
        horizontalOffset: 3
        verticalOffset: 3
        radius: 8.0
        samples: 17
        color: "#40000000"
        transparentBorder: true
    }
    layer.enabled: true
    */
}
