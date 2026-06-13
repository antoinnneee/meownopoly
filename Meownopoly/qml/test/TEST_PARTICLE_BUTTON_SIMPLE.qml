import QtQuick
import QtQuick.Controls
import ui_item
import theme

/**
 * Exemple simple d'intégration du ParticleButton
 * Démonstration minimale pour un démarrage rapide
 */
Rectangle {
    anchors.fill: parent
    color: Theme.background
    
    Column {
        anchors.centerIn: parent
        spacing: 30
        
        // Titre
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Exemple Simple"
            font.pixelSize: Theme.fontSizeDisplay
            font.bold: true
            color: Theme.textPrimary
        }
        
        // Exemple 1 : Configuration par défaut
        ParticleButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Cliquez-moi ! 🎉"
            onClicked: {
                resultText.text = "Bouton cliqué à " + new Date().toLocaleTimeString()
                resultText.color = "#FFD700"
            }
        }
        
        // Exemple 2 : Bouton personnalisé
        ParticleButton {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Bouton Vert 🍃"
            particleColor: "#32CD32"
            particleColorVariation: "#00FF00"
            particleCount: 30
            
            background: Rectangle {
                color: parent.down ? "#28A028" : "#32B032"
                radius: 8
                border.color: parent.hovered ? "#FFFFFF" : "#229022"
                border.width: 2
            }
            
            onClicked: {
                resultText.text = "Succès ! ✓"
                resultText.color = "#32CD32"
            }
        }
        
        // Zone d'affichage du résultat
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 300
            height: 60
            color: Theme.surface
            radius: Theme.radiusL
            border.color: Theme.accent
            border.width: 1

            Text {
                id: resultText
                anchors.centerIn: parent
                text: "Cliquez sur un bouton..."
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.textSecondary
                
                Behavior on color {
                    ColorAnimation { duration: 300 }
                }
            }
        }
    }
}

