import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Placeholder pour la création de session
 * À implémenter dans une version future
 */
Rectangle {
    id: root
    
    color: "#1a1a1a"
    
    signal backRequested()
    signal sessionCreated()
    
    Text {
        anchors.centerIn: parent
        text: "🚧 Création de Session\n\nÀ implémenter prochainement"
        color: "#ffffff"
        font.pixelSize: 24
        horizontalAlignment: Text.AlignHCenter
    }
}
