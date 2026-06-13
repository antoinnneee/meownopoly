import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Game
import Case
import Player
import AssetManager
import theme

Rectangle {
    id: root
    color: playerData ? playerData.color : "#ecf0f1"
    border.color: "#bdc3c7"
    border.width: 1
    radius: 4

    required property Player playerData
    property bool isHovered: false

    // Contenu pour afficher les informations du joueur
    Item {
        id: contentContainer
        anchors.fill: parent
        
        // Avatar du joueur
        Rectangle {
            id: avatarContainer
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }
            height: parent.height * 0.6
            color: "transparent"
            
            Image {
                id: avatarImage
                anchors.centerIn: parent
                width: Math.min(parent.width, parent.height) * 0.8
                height: width
                source: playerData && playerData.indexLogo >= 0 ? 
                   AssetManager.getAssetPath("ui", "avatar", "avatar" + (playerData.indexLogo + 1)) :
                    AssetManager.getAssetPath("avatar/noAvatar.png")
                fillMode: Image.PreserveAspectFit
            }
        }
        
        // Informations du joueur
        ColumnLayout {
            anchors {
                top: avatarContainer.bottom
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: Theme.spacingXS
            }
            spacing: Theme.spacingXXS
            
            // Nom du joueur
            Label {
                Layout.fillWidth: true
                text: playerData ? playerData.name : "Joueur"
                font.bold: true
                font.pixelSize: Theme.fontSizeCaption
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: getContrastTextColor(root.color)
            }
            
            // Kibbles (monnaie)
            Label {
                Layout.fillWidth: true
                text: playerData ? playerData.kibble + " Kibbles" : "0 Kibbles"
                font.pixelSize: Theme.fontSizeTiny
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: getContrastTextColor(root.color)
            }
            
            // Propriétés
            Label {
                Layout.fillWidth: true
                text: playerData ? "Propriétés: " + playerData.propertyCount : "Propriétés: 0"
                font.pixelSize: Theme.fontSizeTiny
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: getContrastTextColor(root.color)
                visible: width > 60
            }
            
            // Statut prison
            Label {
                Layout.fillWidth: true
                text: playerData && playerData.inJail ? "En prison" : ""
                font.pixelSize: Theme.fontSizeTiny
                font.italic: true
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                color: Theme.danger
                visible: playerData && playerData.inJail
            }
        }
    }

    // Mouse area for interaction
    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        z: 100

        onEntered: root.isHovered = true
        onExited: root.isHovered = false
        onClicked: {
            console.log("Joueur sélectionné:", playerData ? playerData.name : "inconnu")
        }
    }
    
    // Fonction pour obtenir une couleur de texte contrastante
    function getContrastTextColor(bgColor) {
        var color = Qt.color(bgColor)
        var luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
        return luminance > 0.5 ? "black" : "white"
    }
}
