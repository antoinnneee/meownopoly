import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ui_item 1.0

/**
 * Test du composant ParticleButton
 * Démontre différentes configurations et utilisations
 */
Rectangle {
    id: testRoot
    anchors.fill: parent
    color: "#1a1a1a"
    
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 40
        
        // Titre
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Test du Bouton à Particules"
            font.pixelSize: 32
            font.bold: true
            color: "white"
        }
        
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Cliquez sur les boutons pour voir l'effet de particules !"
            font.pixelSize: 16
            color: "#CCCCCC"
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
            Layout.topMargin: 20
            width: 300
            height: 80
            color: "#2C2C2C"
            radius: 10
            border.color: "#4A90E2"
            border.width: 2
            
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 5
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Nombre de clics"
                    font.pixelSize: 14
                    color: "#CCCCCC"
                }
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: clickCounter.count
                    font.pixelSize: 36
                    font.bold: true
                    color: "#4A90E2"
                }
            }
            
            // Animation du compteur
            Behavior on scale {
                SequentialAnimation {
                    NumberAnimation { from: 1.0; to: 1.2; duration: 100 }
                    NumberAnimation { from: 1.2; to: 1.0; duration: 100 }
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
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
        
        // Instructions
        Rectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 10
            width: 400
            height: 100
            color: "#2C2C2C"
            radius: 10
            
            ColumnLayout {
                anchors.centerIn: parent
                anchors.margins: 10
                spacing: 5
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "💡 Astuce"
                    font.pixelSize: 16
                    font.bold: true
                    color: "#FFD700"
                }
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Chaque bouton a une configuration différente :"
                    font.pixelSize: 12
                    color: "#CCCCCC"
                    wrapMode: Text.WordWrap
                }
                
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "couleur, nombre de particules, taille, durée..."
                    font.pixelSize: 12
                    color: "#CCCCCC"
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}

