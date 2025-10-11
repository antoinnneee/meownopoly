import QtQuick 2.15
import QtQuick.Controls
import Game
import Case
import Player

import ItemSnapable

import "../../case"
import "snapable"

SnapableElement {
    id: root

    required property Player playerData

    // Configuration du redimensionnement
    isResizable: true
    autoSnap: true
    unitSizeWidth: 5 // Taille par défaut
    unitSizeHeight: 6 // Taille par défaut

    // Paramètres d'affichage visuel
    property alias backgroundColor: playerTile.color
    property alias isHovered: playerTile.isHovered

    // Configuration de l'état d'interaction
    z: isSelected ? 100 : 1

    // Effet de sélection
    Rectangle {
        visible: root.isSelected
        anchors.fill: parent
        anchors.margins: -3
        radius: 6
        color: "transparent"
        border.width: 2
        border.color: "#2980b9"
    }

    // Affichage du joueur avec PlayerTile
    PlayerTile {
        id: playerTile
        anchors.fill: parent
        playerData: root.playerData
        z: 1  // Assurer que le contenu est sous les poignées
    }
    
    // Gestion des signaux de redimensionnement
    onElementResized: function(element, newWidth, newHeight) {
        // Mettre à jour les dimensions selon la grille
        console.log("Joueur redimensionné:", newWidth, "x", newHeight)
    }
    
    // Gestion du placement sur la grille
    onSnapCompleted: function(element) {
        console.log("Joueur placé sur la grille à:", element.gridRelativePositionX, element.gridRelativePositionY)
    }
    
    // Menu contextuel spécifique aux joueurs
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                contextMenu.popup()
            }
        }
    }
    
    // Menu contextuel pour le joueur
    Menu {
        id: contextMenu
        
        MenuItem {
            text: "Configurer le joueur"
            onTriggered: {
                root.elementConfigurationRequested(root)
            }
        }
        
        MenuItem {
            text: "Connexions"
            onTriggered: {
                root.elementConnectionsConfigurationRequested(root)
            }
        }
        
        MenuSeparator {}
        
        MenuItem {
            text: "Supprimer"
            onTriggered: {
                root.elementDeleted(root)
            }
        }
    }
}
