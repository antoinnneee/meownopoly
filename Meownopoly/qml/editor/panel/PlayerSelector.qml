import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Player
import MeowStyle

Rectangle {
    id: root
    
    // Propriétés
    property Player currentPlayer: null
    property bool updatingValues: false
    
    // Signaux
    signal playerPropertyChanged(string property, var newValue)
    
    // Style
    height: 150
    color: "#ffffff"
    border.color: "#ced4da"
    border.width: 2
    radius: 8
    
    // Avatars disponibles
    property var availableAvatars: [0, 1, 2, 3, 4, 5]  // Indices 0-5 pour les avatars 1-6
    property var availableColors: [
        "#e74c3c", // Rouge
        "#3498db", // Bleu
        "#2ecc71", // Vert
        "#f39c12", // Orange
        "#9b59b6", // Violet
        "#1abc9c"  // Turquoise
    ]
    
    // Index actuel dans la liste des avatars
    property int currentAvatarIndex: currentPlayer ? (currentPlayer.indexLogo >= 0 ? currentPlayer.indexLogo : 0) : 0
    property int currentColorIndex: getColorIndex(currentPlayer ? currentPlayer.color : "#e74c3c")
    
    // Obtenir l'index de la couleur actuelle
    function getColorIndex(color) {
        for (let i = 0; i < availableColors.length; i++) {
            if (Qt.colorEqual(color, availableColors[i])) {
                return i;
            }
        }
        return 0;
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        // Nom du joueur
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 30
            
            Text {
                text: "Nom :"
                font.pixelSize: 14
                color: "#212529"
                Layout.preferredWidth: 60
            }
            
            TextField {
                id: nameField
                Layout.fillWidth: true
                text: currentPlayer ? currentPlayer.name : ""
                placeholderText: "Nom du joueur"
                
                onTextChanged: {
                    if (!updatingValues && currentPlayer) {
                        playerPropertyChanged("name", text)
                    }
                }
            }
        }
        
        // Avatar du joueur
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            
            // Bouton flèche gauche
            Button {
                id: leftArrowAvatar
                Layout.preferredWidth: 40
                Layout.fillHeight: true
                
                background: Rectangle {
                    color: parent.hovered ? "#e9ecef" : "transparent"
                    radius: 4
                    border.color: parent.hovered ? "#adb5bd" : "transparent"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: "◀"
                    font.pixelSize: 16
                    font.bold: true
                    color: leftArrowAvatar.enabled ? "#495057" : "#adb5bd"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                enabled: currentAvatarIndex > 0
                
                onClicked: {
                    if (currentAvatarIndex > 0 && !updatingValues && currentPlayer) {
                        let newIndex = currentAvatarIndex - 1
                        root.currentAvatarIndex = newIndex
                        playerPropertyChanged("indexLogo", newIndex)
                    }
                }
                
                hoverEnabled: true
                ToolTip.visible: hovered
                ToolTip.text: "Avatar précédent"
                ToolTip.delay: 500
            }
            
            // Zone centrale avec l'avatar
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                Image {
                    anchors.centerIn: parent
                    source: ""//appInstance.getAssetPath("avatar/avatar" + (currentAvatarIndex + 1) + ".png")
                    width: 50
                    height: 50
                    fillMode: Image.PreserveAspectFit
                }
            }
            
            // Bouton flèche droite
            Button {
                id: rightArrowAvatar
                Layout.preferredWidth: 40
                Layout.fillHeight: true
                
                background: Rectangle {
                    color: parent.hovered ? "#e9ecef" : "transparent"
                    radius: 4
                    border.color: parent.hovered ? "#adb5bd" : "transparent"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: "▶"
                    font.pixelSize: 16
                    font.bold: true
                    color: rightArrowAvatar.enabled ? "#495057" : "#adb5bd"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                enabled: currentAvatarIndex < availableAvatars.length - 1
                
                onClicked: {
                    if (currentAvatarIndex < availableAvatars.length - 1 && !updatingValues && currentPlayer) {
                        let newIndex = currentAvatarIndex + 1
                        root.currentAvatarIndex = newIndex
                        playerPropertyChanged("indexLogo", newIndex)
                    }
                }
                
                hoverEnabled: true
                ToolTip.visible: hovered
                ToolTip.text: "Avatar suivant"
                ToolTip.delay: 500
            }
        }
        
        // Couleur du joueur
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            
            // Bouton flèche gauche
            Button {
                id: leftArrowColor
                Layout.preferredWidth: 40
                Layout.fillHeight: true
                
                background: Rectangle {
                    color: parent.hovered ? "#e9ecef" : "transparent"
                    radius: 4
                    border.color: parent.hovered ? "#adb5bd" : "transparent"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: "◀"
                    font.pixelSize: 16
                    font.bold: true
                    color: leftArrowColor.enabled ? "#495057" : "#adb5bd"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                enabled: currentColorIndex > 0
                
                onClicked: {
                    if (currentColorIndex > 0 && !updatingValues && currentPlayer) {
                        let newIndex = currentColorIndex - 1
                        root.currentColorIndex = newIndex
                        playerPropertyChanged("color", availableColors[newIndex])
                    }
                }
                
                hoverEnabled: true
                ToolTip.visible: hovered
                ToolTip.text: "Couleur précédente"
                ToolTip.delay: 500
            }
            
            // Zone centrale avec la couleur
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "transparent"
                
                Rectangle {
                    anchors.centerIn: parent
                    width: 100
                    height: 30
                    color: availableColors[currentColorIndex]
                    radius: 4
                    border.color: "#000000"
                    border.width: 1
                }
            }
            
            // Bouton flèche droite
            Button {
                id: rightArrowColor
                Layout.preferredWidth: 40
                Layout.fillHeight: true
                
                background: Rectangle {
                    color: parent.hovered ? "#e9ecef" : "transparent"
                    radius: 4
                    border.color: parent.hovered ? "#adb5bd" : "transparent"
                    border.width: 1
                }
                
                contentItem: Text {
                    text: "▶"
                    font.pixelSize: 16
                    font.bold: true
                    color: rightArrowColor.enabled ? "#495057" : "#adb5bd"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                
                enabled: currentColorIndex < availableColors.length - 1
                
                onClicked: {
                    if (currentColorIndex < availableColors.length - 1 && !updatingValues && currentPlayer) {
                        let newIndex = currentColorIndex + 1
                        root.currentColorIndex = newIndex
                        playerPropertyChanged("color", availableColors[newIndex])
                    }
                }
                
                hoverEnabled: true
                ToolTip.visible: hovered
                ToolTip.text: "Couleur suivante"
                ToolTip.delay: 500
            }
        }
    }
    
    // Fonction publique pour mettre à jour le joueur depuis l'extérieur
    function updateControls() {
        if (!currentPlayer) return;
        
        updatingValues = true;
        
        nameField.text = currentPlayer.name || "";
        currentAvatarIndex = currentPlayer.indexLogo >= 0 ? currentPlayer.indexLogo : 0;
        currentColorIndex = getColorIndex(currentPlayer.color);
        
        updatingValues = false;
    }
}
