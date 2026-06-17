import QtQuick
import QtQuick.Particles

import ui_item

/**
 * ParticleButton — MeowButton agrémenté d'un jet de particules au clic.
 *
 * Toute la stylistique (fond, libellé, feedback de scale et de survol)
 * provient de MeowButton ; ce composant n'ajoute que l'émetteur de
 * particules émises en arc de cercle vers le haut puis retombant avec
 * gravité.
 */
MeowButton {
    id: particleButton

    // ── Personnalisation des particules ──────────────────────────
    property color particleColor: "#FFD700"          // Couleur dorée par défaut
    property color particleColorVariation: "#FF6B6B" // Variation de couleur
    property int particleCount: 20                   // Nombre de particules par clic
    property int particleSize: 8                     // Taille des particules
    property int particleLifeSpan: 2000              // Durée de vie en ms
    property string particleImage: "qrc:///particleresources/glowdot.png"

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
                lifeSpan: particleButton.particleLifeSpan
                size: particleButton.particleSize
                endSize: particleButton.particleSize / 2

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
                source: particleButton.particleImage
                color: particleButton.particleColor
                colorVariation: 0.3
                alpha: 0.8
                alphaVariation: 0.2
                rotation: 0
                rotationVariation: 360
                rotationVelocityVariation: 180

                // Effet de fade out en fin de vie
                Gradient {
                    GradientStop { position: 0.0; color: particleButton.particleColor }
                    GradientStop { position: 0.8; color: particleButton.particleColorVariation }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // Émission des particules au clic. Le feedback de scale est géré par
    // MeowButton (via Connections), il survit donc à ce handler.
    onClicked: particleEmitter.burst(particleCount)
}
