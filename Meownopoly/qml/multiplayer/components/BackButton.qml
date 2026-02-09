import QtQuick
import QtQuick.Controls

/**
 * Bouton retour réutilisable avec flèche
 * Utilisé dans MultiplayerLobby et SessionDetails
 */
Rectangle {
    id: root
    
    width: 40
    height: 40
    color: mouseArea.containsMouse ? "#444444" : "#333333"
    radius: 8
    
    signal backClicked()
    
    // Animation de couleur
    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }
    
    // Flèche de retour
    Text {
        text: "←"
        color: "#ffffff"
        font.pixelSize: 24
        anchors.centerIn: parent
    }
    
    // Interaction
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: root.backClicked()
    }
    
    // Effet de pression
    scale: mouseArea.pressed ? 0.95 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutQuad
        }
    }
}
