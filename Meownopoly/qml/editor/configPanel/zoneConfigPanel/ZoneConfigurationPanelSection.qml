import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ui_item

CollapsableGroupBox {
    id: root
    title: "Configuration de Zone"
    
    // Properties
    property bool updatingValues: false
    property var logic: null
    property alias zoneName: generalSection.zoneName
    property alias exclusion: generalSection.exclusion
    property alias speedMultiplier: generalSection.speedMultiplier
    property alias accelerationMultiplier: generalSection.accelerationMultiplier
    property alias frictionStrength: generalSection.frictionStrength
    
    // Signals
    signal configurationChanged()
    signal focusReleased()
    
    // Main content
    content: [
        // General Section (Name, Exclusion)
        ZCP_GeneralSection {
            id: generalSection
            Layout.fillWidth: true
            updatingValues: root.updatingValues
            
            onConfigurationChanged: root.configurationChanged()
            onFocusReleased:root.focusReleased()
        },

        // Directions & Velocity Strength Section
        ZCP_DirectionsSection {
            id: directionsSection
            Layout.fillWidth: true
            updatingValues: root.updatingValues

            onConfigurationChanged: root.configurationChanged()
            onFocusReleased:root.focusReleased()
        },

        // Déclencheur "plaque de pression" (caisse dans la zone → ouvre les
        // éléments liés / crédite une récompense).
        ZCP_TriggerSection {
            id: triggerSection
            Layout.fillWidth: true
            updatingValues: root.updatingValues

            onConfigurationChanged: root.configurationChanged()
            onFocusReleased: root.focusReleased()
        }
    ]

    function getCurrentPhysicSettings() {
        return {
            zoneName: generalSection.zoneName,
            exclusion: generalSection.exclusion,
            speedMultiplier: generalSection.speedMultiplier,
            velocityDirectionX: directionsSection.velocityDirectionX,
            velocityDirectionY: directionsSection.velocityDirectionY,
            velocityStrength: directionsSection.velocityStrength,
            frictionStrength: generalSection.frictionStrength,
            accelerationMultiplier: generalSection.accelerationMultiplier,
            screenEffectId: generalSection.screenEffectId,
            triggerMode: triggerSection.triggerMode,
            triggerOnce: triggerSection.triggerOnce,
            rewardCurrency: triggerSection.rewardCurrency,
            rewardItemName: triggerSection.rewardItemName,
            rewardItemQuantity: triggerSection.rewardItemQuantity
        }
    }
    function updateFromZoneParameter(zoneParam) {
      if (root.effectsLocked) return

        // Update sliders from target values
        generalSection.updateFromZoneParameter(zoneParam)
        directionsSection.updateFromZoneParameter(zoneParam)
        triggerSection.updateFromZoneParameter(zoneParam)
    }
}
