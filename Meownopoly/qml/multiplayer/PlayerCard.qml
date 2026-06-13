import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

/**
 * Carte représentant un joueur dans une session
 * Utilisée comme delegate dans Repeater (4 instances)
 */
Rectangle {
    id: root
    
    // Props requises du model
     property string nickname
     property string avatar
     property bool isHost
    
    width: parent.width
    height: 60
    color: Theme.surface
    radius: Theme.radiusL
    border.color: Theme.border
    border.width: 1

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingXL
        
        // GAUCHE: Avatar emoji
        Text {
            text: root.avatar
            font.pixelSize: Theme.fontSizeDisplay
            Layout.alignment: Qt.AlignVCenter
        }
        
        // CENTRE: Pseudo du joueur
        Text {
            text: root.nickname
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeLarge
            font.bold: true
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
        }
        
        // DROITE: Badge hôte (visible seulement si isHost = true)
        Rectangle {
            visible: root.isHost
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            radius: 16
            color: Theme.warning
            border.color: "#ffffff"
            border.width: 2
            Layout.alignment: Qt.AlignVCenter
            
            Text {
                text: "👑"
                font.pixelSize: Theme.fontSizeLarge
                anchors.centerIn: parent
            }
            
            // Tooltip pour expliquer le badge
            ToolTip {
                visible: hostMouseArea.containsMouse
                text: "Hôte de la session"
                delay: 500
            }
            
            MouseArea {
                id: hostMouseArea
                anchors.fill: parent
                hoverEnabled: true
            }
            
            // Animation pulse subtile pour le badge hôte
            SequentialAnimation on scale {
                running: root.isHost
                loops: Animation.Infinite
                NumberAnimation { from: 1.0; to: 1.1; duration: 1000; easing.type: Easing.InOutQuad }
                NumberAnimation { from: 1.1; to: 1.0; duration: 1000; easing.type: Easing.InOutQuad }
            }
        }
    }
    
    // Animation d'apparition en cascade
    opacity: 0
    Component.onCompleted: fadeIn.start()
    
    NumberAnimation {
        id: fadeIn
        target: root
        property: "opacity"
        from: 0
        to: 1
        duration: 300
        easing.type: Easing.OutQuad
    }
}
