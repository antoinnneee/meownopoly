import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

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
    color: "#2a2a2a"
    radius: 8
    border.color: "#444444"
    border.width: 1
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        
        // GAUCHE: Avatar emoji
        Text {
            text: root.avatar
            font.pixelSize: 24
            Layout.alignment: Qt.AlignVCenter
        }
        
        // CENTRE: Pseudo du joueur
        Text {
            text: root.nickname
            color: "#ffffff"
            font.pixelSize: 16
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
            color: "#ff9800"
            border.color: "#ffffff"
            border.width: 2
            Layout.alignment: Qt.AlignVCenter
            
            Text {
                text: "👑"
                font.pixelSize: 16
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
