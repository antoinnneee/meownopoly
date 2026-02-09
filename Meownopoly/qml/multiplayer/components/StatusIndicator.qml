import QtQuick
import QtQuick.Layouts

/**
 * Indicateur de statut de connexion réutilisable
 * Affiche l'état en ligne/hors ligne avec ping
 */
Row {
    id: root
    
    spacing: 8
    
    property bool isOnline: true
    property int ping: 45
    
    // Emoji de connexion avec animation pulse
    Text {
        id: connectionEmoji
        text: "🛜"
        font.pixelSize: 16
        anchors.verticalCenter: parent.verticalCenter
        
        // Animation pulse subtile
        SequentialAnimation on opacity {
            running: root.isOnline
            loops: Animation.Infinite
            NumberAnimation { from: 1.0; to: 0.6; duration: 1500; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 0.6; to: 1.0; duration: 1500; easing.type: Easing.InOutQuad }
        }
    }
    
    // Texte de statut
    Text {
        text: root.isOnline ? "En ligne (" + root.ping + "ms)" : "Hors ligne"
        color: root.isOnline ? "#4caf50" : "#f44336"
        font.pixelSize: 14
        anchors.verticalCenter: parent.verticalCenter
        
        // Animation de couleur
        Behavior on color {
            ColorAnimation {
                duration: 300
                easing.type: Easing.OutQuad
            }
        }
    }
}
