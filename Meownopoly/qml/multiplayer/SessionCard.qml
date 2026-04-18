import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Carte cliquable représentant une session de jeu
 * Utilisée comme delegate dans ListView (5 instances)
 */
Rectangle {
    id: root
    
    // Props requises du model
     property string name
     property string sessionId
     property int players
     property int maxPlayers
     property string hostNickname // Nouveau
     property int onlineCount     // Nouveau

     // détection du prefix "[EDIT:<hostId>]" pour décorer la carte
     // et afficher un nom propre à l'utilisateur.
     readonly property var _editInfo: {
         const re = /^\[EDIT:([^\]]+)\]\s*(.*)$/
         const m = re.exec(root.name || "")
         return m ? { isEdit: true, hostId: m[1], cleanName: m[2] || "" }
                  : { isEdit: false, hostId: "", cleanName: root.name || "" }
     }
     readonly property bool isEditorSession: _editInfo.isEdit
     readonly property string displayName: _editInfo.cleanName
    
    width: ListView.view.width - 32
    height: 90
    color: "#2a2a2a"
    radius: 12
    
    // Bordure colorée selon disponibilité (ou violette pour session éditeur).
    border.width: 2
    border.color: {
        if (root.isEditorSession) return "#a78bfa"           // Violet: session éditeur
        if (players === maxPlayers) return "#ff9800"          // Orange: pleine
        if (players >= maxPlayers * 0.75) return "#ffeb3b"    // Jaune: presque pleine
        return "#4caf50"                                       // Vert: disponible
    }
    
    // Animation de bordure
    Behavior on border.color {
        ColorAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }
    
    signal clicked()
    
    RowLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 16
        
        // GAUCHE: Informations de la session
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            
            // Nom de la session (prefix "[EDIT:...]" stripé, 🛠️ ajouté).
            Text {
                text: (root.isEditorSession ? "🛠️ " : "")
                      + "Name: " + root.displayName
                color: "#ffffff"
                font.pixelSize: 18
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            
            // ID de la session
            Text {
                text: "ID: " + root.sessionId
                color: "#888888"
                font.pixelSize: 12
                font.family: "Consolas, Monaco, monospace"
            }
            
            // Hôte
            Text {
                text: "👤 Hôte : " + (root.hostNickname ? root.hostNickname : "Inconnu")
                color: "#aaaaaa"
                font.pixelSize: 12
            }
        }
        
        // CENTRE: Online Status
        ColumnLayout {
            Layout.alignment: Qt.AlignRight
            spacing: 2
            
            Text {
                text: "En ligne"
                color: "#888888"
                font.pixelSize: 10
                Layout.alignment: Qt.AlignHCenter
            }
            
            Text {
                text: "🟢 " + root.onlineCount
                color: "#4caf50"
                font.pixelSize: 14
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
        
        // DROITE: Badge compteur de joueurs
        Rectangle {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60
            radius: 30
            color: root.players === root.maxPlayers ? "#ff9800" : "#4caf50"
            border.color: "#ffffff"
            border.width: 2
            
            // Animation de couleur
            Behavior on color {
                ColorAnimation {
                    duration: 200
                    easing.type: Easing.OutQuad
                }
            }
            
            Column {
                anchors.centerIn: parent
                spacing: 2
                
                Text {
                    text: root.players + "/" + root.maxPlayers
                    color: "#ffffff"
                    font.pixelSize: 16
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "joueurs"
                    color: "#ffffff"
                    font.pixelSize: 9
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }
    
    // MouseArea pour l'interaction
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        
        onClicked: root.clicked()
    }
    
    // Effet hover: scale et luminosité
    scale: mouseArea.containsMouse ? 1.02 : 1.0
    opacity: mouseArea.pressed ? 0.9 : 1.0
    
    Behavior on scale {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutQuad
        }
    }
    
    Behavior on opacity {
        NumberAnimation {
            duration: 100
            easing.type: Easing.OutQuad
        }
    }
    
    // Ombre portée
    layer.enabled: true
    layer.effect: ShaderEffect {
        property real shadowOpacity: mouseArea.containsMouse ? 0.4 : 0.2
        
        Behavior on shadowOpacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
    }
}
