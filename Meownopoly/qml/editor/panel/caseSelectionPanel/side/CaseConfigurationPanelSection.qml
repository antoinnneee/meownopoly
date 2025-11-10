import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import "../../../../ui_item"

CollapsableGroupBox {
    id: root
    title: "Configuration de case"
    
    // Properties
    property var targetSnapableCase: null
    property var targetCase: null
    property bool updatingValues: false
    property var logic: null  // Référence au logic pour sauvegarder

    // Signals
    signal requestChangeType(var newType)
    signal configurationChanged()

    
    // Main scrollable content
     content: ScrollView {
         Layout.fillWidth: true
         Layout.fillHeight: true
        contentWidth: availableWidth
        clip: true
        
        Column {
            id: mainLayout
            width: parent.width
            spacing: 10
            
            // Type Selector Section
            CCPS_TypeSection {
                id: typeSection
                width: parent.width
                targetCase: root.targetCase
                updatingValues: root.updatingValues
                
                onTypeChanged: function(newType) {
                    if (!root.updatingValues && targetCase) {
                        requestChangeType(newType);
                    }
                }
            }
            
            // General Configuration Section
            CCPS_GeneralSection {
                id: generalSection
                width: parent.width
                targetCase: root.targetCase
                updatingValues: root.updatingValues
                logic: root.logic
                
                onConfigurationChanged: root.configurationChanged()
            }
            
            // Specific Configuration Sections (visible according to case type)
            CCPS_RestAreaSection {
                id: restAreaSection
                width: parent.width
                targetCase: root.targetCase
                updatingValues: root.updatingValues
                logic: root.logic
                visible: targetCase && targetCase.type === Case.CS_RestArea
                
                onConfigurationChanged: root.configurationChanged()
            }
            
            CCPS_KibbleDispenserSection {
                id: kibbleDispenserSection
                width: parent.width
                targetCase: root.targetCase
                updatingValues: root.updatingValues
                logic: root.logic
                visible: targetCase && targetCase.type === Case.CS_KibbleDispenser
                
                onConfigurationChanged: root.configurationChanged()
            }
            
            CCPS_CardBoardBoxSection {
                id: cardBoardBoxSection
                width: parent.width
                targetCase: root.targetCase
                updatingValues: root.updatingValues
                logic: root.logic
                visible: targetCase && targetCase.type === Case.CS_CardBoardBox
                
                onConfigurationChanged: root.configurationChanged()
            }
            
            CCPS_CatDeviceSection {
                id: catDeviceSection
                width: parent.width
                targetCase: root.targetCase
                updatingValues: root.updatingValues
                logic: root.logic
                visible: targetCase && targetCase.type === Case.CS_Device
                
                onConfigurationChanged: root.configurationChanged()
            }
        }
    }
    
    // Functions
    function setTargetCase(snapableCase) {
        if (snapableCase && snapableCase.snapableParameters.caseData !== undefined) {
            targetSnapableCase = snapableCase
            targetCase = snapableCase.snapableParameters.caseData
            updateControls()
        }
    }
    
    function updateControls() {
        if (!targetCase) return
        
        updatingValues = true
        
        // Update general section
        generalSection.updateControls()
        
        // Update specific sections
        if (targetCase.type === Case.CS_RestArea) {
            restAreaSection.updateControls()
        } else if (targetCase.type === Case.CS_KibbleDispenser) {
            kibbleDispenserSection.updateControls()
        } else if (targetCase.type === Case.CS_CardBoardBox) {
            cardBoardBoxSection.updateControls()
        } else if (targetCase.type === Case.CS_Device) {
            catDeviceSection.updateControls()
        }
        
        updatingValues = false
    }
    
    function clearTarget() {
        targetSnapableCase = null
        targetCase = null
    }
}
