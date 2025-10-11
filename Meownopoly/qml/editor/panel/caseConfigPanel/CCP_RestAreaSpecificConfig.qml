import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

CCP_PanelElement {
    title: "Configuration Rest Area"
    visible: targetCase && targetCase.type === Case.CS_RestArea

    property alias caseRestAreaFamilyConfig: caseRestAreaFamilyConfig
    property alias caseCatPerksConfig: caseCatPerksConfig
    property alias caseRentConfig: caseRentConfig
    property alias caseHouseHotelPriceConfig: caseHouseHotelPriceConfig

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        if (!targetCase) return
        caseCatPerksConfig.updateControls()
        caseRestAreaFamilyConfig.updateControls()
        caseRentConfig.updateControls()
        caseHouseHotelPriceConfig.updateControls()
    }
    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        
        // Note explicative
        Text {
            text: "🏠 Configuration spécifique aux zones de repos (terrains)"
            font.italic: true
            font.pixelSize: 12
            color: "#6c757d"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            Layout.bottomMargin: 5
        }

        // Configuration de la famille
        CCP_RestAreaFamilyConfig {
            id: caseRestAreaFamilyConfig
            targetCase: root.targetCase
            Layout.fillWidth: true
        }

        // Configuration des prix CaseCatPerks
        CCP_CatPerksConfig {
            id: caseCatPerksConfig
            targetCase: root.targetCase
            Layout.fillWidth: true
        }

        // Prix d'achat des améliorations (maisons/hôtels)
        CCP_HouseHotelPriceConfig {
            id: caseHouseHotelPriceConfig
            targetCase: root.targetCase
            Layout.fillWidth: true
        }

        // Prix de location
        CCP_RentConfig {
            id: caseRentConfig
            targetCase: root.targetCase
            Layout.fillWidth: true
        }
    }
}
