import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import Case
import MapTypes

import ui_item
import theme

CollapsableGroupBox {
    id: control
    title: "Configuration Rest Area"
    
    // Properties
    property var targetCase: null
    property bool updatingValues: false
    property var logic: null  // Référence au logic pour sauvegarder
    
    // Signals
    signal configurationChanged()
    
    onConfigurationChanged: {
        if (logic) {
            logic.saveMap(MapTypes.UNDOREDO)
        }
    }

    content: [
        // Note explicative
        Text {
            text: "🏠 Configuration spécifique aux zones de repos (terrains)"
            font.italic: true
            font.pixelSize: Theme.fontSizeCaption
            color: Theme.textMuted
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        },
        
        // Configuration de la famille
        CCP_RestAreaFamilyConfig {
            id: familyConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
            
            // Apply dark style to the nested component
            Component.onCompleted: {
                if (familyConfig.background) {
                    familyConfig.background.color = Theme.surface
                }
            }
        },
        
        // Configuration des prix CaseCatPerks
        CCP_CatPerksConfig {
            id: catPerksConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
        },
        
        // Prix d'achat des améliorations (maisons/hôtels)
        CCP_HouseHotelPriceConfig {
            id: housePriceConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
        },
        
        // Prix de location
        CCP_RentConfig {
            id: rentConfig
            targetCase: control.targetCase
            Layout.fillWidth: true
        }
    ]
    
    // Functions
    function updateControls() {
        if (!targetCase) return
        
        familyConfig.updateControls()
        catPerksConfig.updateControls()
        housePriceConfig.updateControls()
        rentConfig.updateControls()
    }
}

