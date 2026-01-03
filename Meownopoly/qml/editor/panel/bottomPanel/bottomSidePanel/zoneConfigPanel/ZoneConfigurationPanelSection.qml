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
    
    // Signals
    signal configurationChanged()
    
    // Main content
    content: [
        // General Section (Name, Exclusion)
        ZCP_GeneralSection {
            id: generalSection
            Layout.fillWidth: true
            updatingValues: root.updatingValues
            
            onConfigurationChanged: root.configurationChanged()
        },

        // Directions & Velocity Strength Section
        ZCP_DirectionsSection {
            id: directionsSection
            Layout.fillWidth: true
            updatingValues: root.updatingValues
            
            onConfigurationChanged: root.configurationChanged()
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
            frictionStrength: directionsSection.frictionStrength,
            accelerationMultiplier: generalSection.accelerationMultiplier
        }
    }
    function updateFromZoneParameter(zoneParam) {
      if (root.effectsLocked) return
        
        // Update sliders from target values
        generalSection.updateFromZoneParameter(zoneParam)
        directionsSection.updateFromZoneParameter(zoneParam)
    }
}
