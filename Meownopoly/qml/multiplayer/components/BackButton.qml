import QtQuick
import QtQuick.Controls
import theme

/**
 * Bouton retour réutilisable avec flèche
 * Utilisé dans MultiplayerLobby et SessionDetails
 */
Rectangle {
    id: root

    width: 40
    height: 40
    color: mouseArea.containsMouse ? Theme.border : Theme.surfaceAlt
    radius: Theme.radiusL

    signal backClicked()

    // Animation de couleur
    Behavior on color {
        ColorAnimation {
            duration: Theme.durationNormal
            easing.type: Easing.OutQuad
        }
    }

    // Flèche de retour
    Text {
        text: "←"
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeDisplay
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
            duration: Theme.durationFast
            easing.type: Easing.OutQuad
        }
    }
}
