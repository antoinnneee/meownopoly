import QtQuick
import QtQuick.Layouts
import theme

/**
 * Indicateur de statut de connexion réutilisable
 * Affiche l'état en ligne/hors ligne avec ping
 */
Row {
    id: root

    spacing: Theme.spacingM
    
    property bool isOnline: true
    // ping en ms ; -1 = pas encore mesuré
    property int ping: -1
    
    // Emoji de connexion avec animation pulse
    Text {
        id: connectionEmoji
        text: "🛜"
        font.pixelSize: Theme.fontSizeLarge
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
        text: root.isOnline
              ? (root.ping >= 0 ? "En ligne (" + root.ping + "ms)" : "En ligne (…)")
              : "Hors ligne"
        color: root.isOnline ? Theme.success : Theme.danger
        font.pixelSize: Theme.fontSizeMedium
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
