import QtQuick
import QtQuick.Controls
import QtQuick.Particles

import theme

/**
 * Bouton avec effet de particules lors du clic
 * Les particules sont émises en arc de cercle vers le haut et retombent avec gravité
 */
Button {
    id: particleButton
    
    // Propriétés personnalisables
    property color particleColor: "#FFD700" // Couleur dorée par défaut
    property color particleColorVariation: "#FF6B6B" // Variation de couleur
    property int particleCount: 20 // Nombre de particules par clic
    property int particleSize: 8 // Taille des particules
    property int particleLifeSpan: 2000 // Durée de vie en ms
    property string particleImage: "qrc:///particleresources/glowdot.png" // Image de particule
    
    // Style du bouton
    width: 150
    height: 50
    
    background: Rectangle {
        color: particleButton.down ? Theme.accent : Theme.hover(Theme.accent)
        radius: Theme.radiusL
        border.color: particleButton.hovered ? Theme.surfaceLight : Theme.pressed(Theme.accent)
        border.width: 2

        // Effet de brillance
        Rectangle {
            anchors.fill: parent
            anchors.margins: Theme.spacingXXS
            radius: Theme.radiusM
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.2) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0.0) }
            }
        }
    }
    
    contentItem: Text {
        text: particleButton.text
        font.pixelSize: Theme.fontSizeLarge
        font.bold: true
        color: Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    
    // Système de particules
    Item {
        id: particleContainer
        anchors.fill: parent
        // S'étend au-dessus et en-dessous du bouton pour voir les particules
        anchors.topMargin: -300
        anchors.bottomMargin: -300
        clip: false
        z: -1 // Derrière le texte du bouton
        
        ParticleSystem {
            id: particleSystem
            anchors.fill: parent
            
            // Émetteur de particules (activé au clic)
            Emitter {
                id: particleEmitter
                enabled: false
                // Position à la base du bouton
                x: particleButton.width / 2
                y: particleButton.height + 300 // Décalage pour compenser le container
                
                // Configuration des particules
                lifeSpan: particleLifeSpan
                size: particleSize
                endSize: particleSize / 2
                
                // Vélocité en arc de cercle vers le haut
                velocity: AngleDirection {
                    angle: 270 // Direction vers le haut (0° = droite, 90° = bas, 270° = haut)
                    angleVariation: 60 // Variation de ±60° pour créer un arc
                    magnitude: 200 // Vitesse initiale
                    magnitudeVariation: 100 // Variation de vitesse
                }
                
                // Effet de gravité pour faire retomber les particules
                acceleration: AngleDirection {
                    angle: 90 // Vers le bas
                    magnitude: 230 // Force de gravité
                }
            }
            
            // Apparence des particules
            ImageParticle {
                id: particles
                source: particleImage
                color: particleColor
                colorVariation: 0.3
                alpha: 0.8
                alphaVariation: 0.2
                rotation: 0
                rotationVariation: 360
                rotationVelocityVariation: 180
                
                // Effet de fade out en fin de vie
                Gradient {
                    GradientStop { position: 0.0; color: particleColor }
                    GradientStop { position: 0.8; color: particleColorVariation }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }
    
    // Animation au clic
    onClicked: {
        // Émission de particules
        particleEmitter.burst(particleCount)
        
        // Animation de pression du bouton
        scaleAnimation.start()
    }
    
    // Animation de scale pour le feedback visuel
    SequentialAnimation {
        id: scaleAnimation
        NumberAnimation {
            target: particleButton
            property: "scale"
            from: 1.0
            to: 0.95
            duration: Theme.durationFast
            easing.type: Easing.OutQuad
        }
        NumberAnimation {
            target: particleButton
            property: "scale"
            from: 0.95
            to: 1.0
            duration: Theme.durationFast
            easing.type: Easing.OutBounce
        }
    }
    
    // Effet de hover
    scale: hovered ? 1.05 : 1.0
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durationNormal
            easing.type: Easing.OutQuad
        }
    }
}

