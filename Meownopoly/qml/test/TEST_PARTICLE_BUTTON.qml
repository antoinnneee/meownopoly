import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ui_item
import theme

/**
 * Test du composant ParticleButton
 * Démontre différentes configurations et utilisations
 */
Rectangle {
    id: testRoot
    anchors.fill: parent
    color: Theme.background
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 40
        
        // Titre
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Test du Bouton à Particules"
            font.pixelSize: Theme.fontSizeHero
            font.bold: true
            color: Theme.textPrimary
        }
        
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Cliquez sur les boutons pour voir l'effet de particules !"
            font.pixelSize: Theme.fontSizeLarge
            color: Theme.textSecondary
        }
        
        // Conteneur pour les boutons
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: 2
            rowSpacing: 30
            columnSpacing: 30
            
            // Bouton 1 : Configuration par défaut (doré)
            ParticleButton {
                text: "Bouton Doré"
                onClicked: {
                    console.log("Bouton Doré cliqué !")
                    clickCounter.count++
                }
            }
            
            // Bouton 2 : Particules bleues
            ParticleButton {
                text: "Bouton Bleu"
                particleColor: "#4A90E2"
                particleColorVariation: "#5AA3F2"
                particleCount: 30
                background: Rectangle {
                    color: parent.down ? "#2E7BC0" : "#3A8AD0"
                    radius: 8
                    border.color: parent.hovered ? "#FFFFFF" : "#2A6AB0"
                    border.width: 2
                }
                onClicked: {
                    console.log("Bouton Bleu cliqué !")
                    clickCounter.count++
                }
            }
            
            // Bouton 3 : Particules roses/violettes
            ParticleButton {
                text: "Bouton Rose"
                particleColor: "#FF69B4"
                particleColorVariation: "#DA70D6"
                particleCount: 25
                particleSize: 10
                background: Rectangle {
                    color: parent.down ? "#D65AA1" : "#E66AB4"
                    radius: 8
                    border.color: parent.hovered ? "#FFFFFF" : "#C64A91"
                    border.width: 2
                }
                onClicked: {
                    console.log("Bouton Rose cliqué !")
                    clickCounter.count++
                }
            }
            
            // Bouton 4 : Particules vertes
            ParticleButton {
                text: "Bouton Vert"
                particleColor: "#32CD32"
                particleColorVariation: "#00FF00"
                particleCount: 40
                particleSize: 6
                particleLifeSpan: 2500
                background: Rectangle {
                    color: parent.down ? "#28A028" : "#32B032"
                    radius: 8
                    border.color: parent.hovered ? "#FFFFFF" : "#229022"
                    border.width: 2
                }
                onClicked: {
                    console.log("Bouton Vert cliqué !")
                    clickCounter.count++
                }
            }
            
            // Bouton 5 : Particules rouges/oranges (effet feu)
            ParticleButton {
                text: "Bouton Feu 🔥"
                particleColor: "#FF4500"
                particleColorVariation: "#FFD700"
                particleCount: 35
                particleSize: 12
                background: Rectangle {
                    color: parent.down ? "#CC3700" : "#DD4710"
                    radius: 8
                    border.color: parent.hovered ? "#FFFFFF" : "#BB3600"
                    border.width: 2
                }
                onClicked: {
                    console.log("Bouton Feu cliqué !")
                    clickCounter.count++
                }
            }
            
            // Bouton 6 : Arc-en-ciel (couleurs aléatoires)
            ParticleButton {
                id: rainbowButton
                text: "Arc-en-ciel 🌈"
                particleCount: 50
                particleSize: 8
                background: Rectangle {
                    color: parent.down ? "#7B68EE" : "#8B78FF"
                    radius: 8
                    border.color: parent.hovered ? "#FFFFFF" : "#6B58DE"
                    border.width: 2
                }
                onClicked: {
                    console.log("Bouton Arc-en-ciel cliqué !")
                    clickCounter.count++
                    // Changer la couleur à chaque clic
                    var colors = ["#FF0000", "#FF7F00", "#FFFF00", "#00FF00", "#0000FF", "#4B0082", "#9400D3"]
                    particleColor = colors[Math.floor(Math.random() * colors.length)]
                }
            }
        }
        
        // Compteur de clics
        Rectangle {
            id: clickCounter
            property int count: 0
            
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.spacingHuge
            width: 300
            height: 80
            color: Theme.surface
            radius: Theme.radiusXL
            border.color: Theme.accent
            border.width: 2

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nombre de clics"
                    font.pixelSize: Theme.fontSizeMedium
                    color: Theme.textSecondary
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: clickCounter.count
                    font.pixelSize: Theme.fontSizeHero
                    font.bold: true
                    color: Theme.accent
                }
            }
            
            // Animation du compteur
            Behavior on scale {
                SequentialAnimation {
                    NumberAnimation { from: 1.0; to: 1.2; duration: Theme.durationFast }
                    NumberAnimation { from: 1.2; to: 1.0; duration: Theme.durationFast }
                }
            }
            
            onCountChanged: {
                scale = 1.0 // Trigger l'animation
            }
        }
        
        // Bouton de réinitialisation
        Button {
            Layout.alignment: Qt.AlignHCenter
            text: "Réinitialiser"
            onClicked: clickCounter.count = 0
            
            background: Rectangle {
                color: parent.down ? "#666666" : "#777777"
                radius: 5
                border.color: parent.hovered ? "#FFFFFF" : "#555555"
                border.width: 1
            }
            
            contentItem: Text {
                text: parent.text
                color: Theme.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        // Instructions
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.spacingL
            width: 400
            height: 100
            color: Theme.surface
            radius: Theme.radiusXL

            ColumnLayout {
                anchors.centerIn: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingXS

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "💡 Astuce"
                    font.pixelSize: Theme.fontSizeLarge
                    font.bold: true
                    color: "#FFD700"
                }
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Chaque bouton a une configuration différente :"
                    font.pixelSize: Theme.fontSizeBody
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                }
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "couleur, nombre de particules, taille, durée..."
                    font.pixelSize: Theme.fontSizeBody
                    color: Theme.textSecondary
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}

