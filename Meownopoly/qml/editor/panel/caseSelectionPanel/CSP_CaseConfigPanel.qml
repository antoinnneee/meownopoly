import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import CaseRestArea
import MeowStyle
import Player
import "../caseConfigPanel"

Rectangle {
    id: root
    color: "#333333"
    radius: 4
    
    // Properties
    property var caseData: null
    property bool isLoading: false
    
    // Signal when configuration changes are applied
    signal configurationApplied(var caseData)
    
    // Spinner to show during loading
    BusyIndicator {
        anchors.centerIn: parent
        running: root.isLoading
        visible: root.isLoading
    }
    
    // Main content - only visible when not loading
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        visible: !root.isLoading
        
        // Title with case name
        Text {
            text: caseData ? "Configuration: " + caseData.name : "Case Configuration"
            color: "white"
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
        }
        
        // Case type indicator
        Rectangle {
            Layout.fillWidth: true
            height: 30
            color: {
                if (caseData) {
                    if (caseData.type === Case.CS_RestArea && caseData.family) {
                        return MeowStyle.familyColors[caseData.family];
                    } else {
                        // Colors based on case type
                        switch (caseData.type) {
                            case Case.CS_KibbleDispenser: return "#FFC107";
                            case Case.CS_CardBoardBox: return "#FF9800";
                            case Case.CS_CatNip: return "#4CAF50";
                            case Case.CS_Jail: return "#9C27B0";
                            case Case.CS_ToJail: return "#673AB7";
                            case Case.CS_CatDoor: return "#2196F3";
                            case Case.CS_FreeNap: return "#03A9F4";
                            case Case.CS_Device: return "#00BCD4";
                            default: return "#607D8B";
                        }
                    }
                }
                return "#607D8B";
            }
            radius: 4
            
            Text {
                anchors.centerIn: parent
                text: caseData ? MeowStyle.getCaseTypeName(caseData.type) : "Unknown Type"
                color: "white"
                font.bold: true
            }
        }
        
        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }
        
        // Configuration content - reusing existing components from caseConfigPanel
        // General configuration for all case types
        CaseGeneralConfig {
            id: caseGeneralConfig
            targetCase: root.caseData
            Layout.fillWidth: true
            visible: root.caseData !== null
        }
        
        // Specific configuration based on case type
        Loader {
            id: specificConfigLoader
            Layout.fillWidth: true
            visible: root.caseData !== null
            
            sourceComponent: {
                if (!root.caseData) return null;
                
                switch (root.caseData.type) {
                    case Case.CS_RestArea:
                        return restAreaConfigComponent;
                    case Case.CS_KibbleDispenser:
                        return kibbleDispenserConfigComponent;
                    case Case.CS_CatDoor:
                        return catDoorConfigComponent;
                    case Case.CS_Device:
                        return catDeviceConfigComponent;
                    case Case.CS_CardBoardBox:
                        return cardBoardBoxConfigComponent;
                    default:
                        return null;
                }
            }
        }
        
        // Apply button
        Button {
            text: "Appliquer"
            Layout.alignment: Qt.AlignRight
            
            background: Rectangle {
                color: "#4CAF50"
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                if (root.caseData) {
                    root.configurationApplied(root.caseData);
                }
            }
        }
    }
    
    // Components for specific case types
    Component {
        id: restAreaConfigComponent
        CaseRestAreaSpecificConfig {
            targetCase: root.caseData
            width: specificConfigLoader.width
        }
    }
    
    Component {
        id: kibbleDispenserConfigComponent
        CaseKibbleDispenserSpecificConfig {
            targetCase: root.caseData
            width: specificConfigLoader.width
        }
    }
    
    Component {
        id: catDoorConfigComponent
        // Here you would have your CatDoorSpecificConfig component
        // Using placeholder for now
        Item {
            width: specificConfigLoader.width
            height: 100
            
            Text {
                anchors.centerIn: parent
                text: "Configuration spécifique pour Porte"
                color: "#AAAAAA"
            }
        }
    }
    
    Component {
        id: catDeviceConfigComponent
        CaseCatDeviceSpecificConfig {
            targetCase: root.caseData
            width: specificConfigLoader.width
        }
    }
    
    Component {
        id: cardBoardBoxConfigComponent
        CaseCardBoardBoxSpecificConfig {
            targetCase: root.caseData
            width: specificConfigLoader.width
        }
    }
    
    // Function to update configuration panel when a new case is selected
    function updateForCase(newCaseData) {
        root.isLoading = true;
        
        // Small delay to show loading indicator
        Qt.callLater(function() {
            root.caseData = newCaseData;
            root.isLoading = false;
        });
    }
}
