import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ui_item

CollapsableGroupBox {
    id: root
    title: "Configuration de Zone"
    
    // Properties
    property var targetSnapableZone: null
    property var targetZoneParameter: null
    property bool updatingValues: false
    property var logic: null
    
    // Signals
    signal configurationChanged()
    
    // Main content
    content: [
        // General Section (Name, Exclusion)
        ZCP_GeneralSection {
            id: generalSection
            Layout.fillWidth: true
            targetZoneParameter: root.targetZoneParameter
            updatingValues: root.updatingValues
            
            onConfigurationChanged: root.configurationChanged()
        },

        // Directions & Velocity Strength Section
        ZCP_DirectionsSection {
            id: directionsSection
            Layout.fillWidth: true
            targetZoneParameter: root.targetZoneParameter
            updatingValues: root.updatingValues
            
            onConfigurationChanged: root.configurationChanged()
        }
    ]
    
    // Functions
    function setTargetZone(snapableZone) {
        if (snapableZone && snapableZone.snapableParameters && 
            snapableZone.snapableParameters.zoneParameter !== undefined) {
            targetSnapableZone = snapableZone
            targetZoneParameter = snapableZone.snapableParameters.zoneParameter
            updateControls()
        }
    }
    
    function updateControls() {
        if (!targetZoneParameter) return
        
        updatingValues = true
        generalSection.updateControls()
        directionsSection.updateControls()
        updatingValues = false
    }
    
    function clearTarget() {
        targetSnapableZone = null
        targetZoneParameter = null
    }
}
