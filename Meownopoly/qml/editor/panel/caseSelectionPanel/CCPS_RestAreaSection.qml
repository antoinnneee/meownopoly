import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import "../caseConfigPanel"

GroupBox {
    id: control
    title: "Configuration Rest Area"
    
    // Properties
    property var targetCase: null
    property bool updatingValues: false
    
    // Signals
    signal configurationChanged()
    
    // Visual styling
    background: Rectangle {
        color: "#333333"
        radius: 4
        border.color: "#555555"
        border.width: 1
    }
    
    label: Text {
        x: control.leftPadding
        width: control.availableWidth
        text: control.title
        color: "#cccccc"
        elide: Text.ElideRight
    }
    
    ColumnLayout {
        anchors.fill: parent
        spacing: 8
        
        // Note explicative
        Text {
            text: "🏠 Configuration spécifique aux zones de repos (terrains)"
            font.italic: true
            font.pixelSize: 10
            color: "#888888"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
        
        // Configuration de la famille
        CCP_RestAreaFamilyConfig {
            id: familyConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
            
            // Apply dark style to the nested component
            Component.onCompleted: {
                if (familyConfig.background) {
                    familyConfig.background.color = "#2a2a2a"
                }
            }
        }
        
        // Configuration des prix CaseCatPerks
        CCP_CatPerksConfig {
            id: catPerksConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
        }
        
        // Prix d'achat des améliorations (maisons/hôtels)
        CCP_HouseHotelPriceConfig {
            id: housePriceConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
        }
        
        // Prix de location
        CCP_RentConfig {
            id: rentConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
        }
    }
    
    // Functions
    function updateControls() {
        if (!targetCase) return
        
        familyConfig.updateControls()
        catPerksConfig.updateControls()
        housePriceConfig.updateControls()
        rentConfig.updateControls()
    }
}

