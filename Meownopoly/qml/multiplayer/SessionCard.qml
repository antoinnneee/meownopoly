import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

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

     // Détection des préfixes éditeur pour décorer la carte et afficher un nom
     // propre. `[EDIT:]` reste compatible ; `[AI-EDIT:]` identifie le parcours
     // de co-construction avec le proposant.
     readonly property var _editInfo: {
         const ai = /^\[AI-EDIT:([^\]]+)\]\s*(.*)$/.exec(root.name || "")
         if (ai)
             return { isEdit: true, isAi: true, hostId: ai[1], cleanName: ai[2] || "" }
         const edit = /^\[EDIT:([^\]]+)\]\s*(.*)$/.exec(root.name || "")
         return edit ? { isEdit: true, isAi: false, hostId: edit[1], cleanName: edit[2] || "" }
                     : { isEdit: false, isAi: false, hostId: "", cleanName: root.name || "" }
     }
     readonly property bool isEditorSession: _editInfo.isEdit
     readonly property bool isAiSession: _editInfo.isAi
     readonly property string displayName: _editInfo.cleanName
    
    width: ListView.view.width - 32
    height: 90
    color: Theme.surface
    radius: Theme.radiusXXL
    
    // Bordure colorée selon disponibilité (ou violette pour session éditeur).
    border.width: 2
    border.color: {
        if (root.isAiSession) return Theme.accentAlt            // Vert: session IA
        if (root.isEditorSession) return "#a78bfa"              // Violet: session éditeur
        if (players === maxPlayers) return Theme.warning      // Orange: pleine
        if (players >= maxPlayers * 0.75) return "#ffeb3b"    // Jaune: presque pleine
        return Theme.success                                  // Vert: disponible
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
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingXXL

        // GAUCHE: Informations de la session
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            
            // Nom de la session (prefix "[EDIT:...]" stripé, 🛠️ ajouté).
            Text {
                text: (root.isAiSession ? "✨ " : (root.isEditorSession ? "🛠️ " : ""))
                      + "Name: " + root.displayName
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            
            // ID de la session
            Text {
                text: "ID: " + root.sessionId
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeBody
                font.family: "Consolas, Monaco, monospace"
            }
            
            // Hôte
            Text {
                text: "👤 Hôte : " + (root.hostNickname ? root.hostNickname : "Inconnu")
                color: Theme.textHint
                font.pixelSize: Theme.fontSizeBody
            }
        }
        
        // CENTRE: Online Status
        ColumnLayout {
            Layout.alignment: Qt.AlignRight
            spacing: Theme.spacingXXS

            Text {
                text: "En ligne"
                color: Theme.textMuted
                font.pixelSize: Theme.fontSizeCaption
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "🟢 " + root.onlineCount
                color: Theme.success
                font.pixelSize: Theme.fontSizeMedium
                font.bold: true
                Layout.alignment: Qt.AlignHCenter
            }
        }
        
        // DROITE: Badge compteur de joueurs
        Rectangle {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60
            radius: 30
            color: root.players === root.maxPlayers ? Theme.warning : Theme.success
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
                spacing: Theme.spacingXXS

                Text {
                    text: root.players + "/" + root.maxPlayers
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                
                Text {
                    text: "joueurs"
                    color: Theme.textPrimary
                    font.pixelSize: Theme.fontSizeTiny
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
            duration: Theme.durationFast
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
