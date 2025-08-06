import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import Player

ConfigPanelElement {
    title: "Configuration Rest Area"
    visible: targetCase && targetCase.type === Case.CS_RestArea

    property alias caseRestAreaFamilyConfig: caseRestAreaFamilyConfig
    property alias caseCatPerksConfig: caseCatPerksConfig
    property alias caseRentConfig: caseRentConfig

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
        CaseRestAreaFamilyConfig {
            id: caseRestAreaFamilyConfig
            targetCase: root.targetCase
            Layout.fillWidth: true
        }

        // Configuration des prix CaseCatPerks
        CaseCatPerksConfig {
            id: caseCatPerksConfig
            targetCase: root.targetCase
            Layout.fillWidth: true
        }

        // Prix de location
        CaseRentConfig {
            id: caseRentConfig
            targetCase: root.targetCase
            Layout.fillWidth: true
        }
    }
}