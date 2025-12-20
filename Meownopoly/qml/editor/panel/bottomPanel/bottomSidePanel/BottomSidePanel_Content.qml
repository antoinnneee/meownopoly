import QtQuick 2.15
import QtQuick.Layouts
import QtQuick.Controls

import visualEffectPanel
import connectionConfigPanel
import caseConfigPanel

ColumnLayout {
    id: panelContent
    signal effectChanged()
    signal connectionRequested(string kind)  // Propager les demandes de connexion

    property var logic
    property alias effectsPanel: effectsPanel
    property alias caseConfigurationPanel: caseConfigurationPanelSection
    property alias connectionsConfigurationPanel: connectionsConfigSection
   // property alias transformSection: transformSection
    property bool blockEffectChangedSignal: false

    VisualEffectsPanel {
        id: effectsPanel
        isCollapsed : true
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillWidth: true

        onEffectChanged: {
            if (panelContent.blockEffectChangedSignal) {
                return
            }
            panelContent.effectChanged()
        }
    }

    // Onglet Configuration Case
    CaseConfigurationPanelSection {
        id: caseConfigurationPanelSection
        isCollapsed : true
        logic: panelContent.logic
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillWidth: true

        // Gérer le changement de type de case
        onRequestChangeType: function(newType) {
            if (targetCase) {
                console.log("Changing case type to:", newType)
                //targetCase.type = newType
                targetSnapableCase.snapableParameters.changeCaseDataType(newType)
                // Mettre à jour les contrôles pour refléter le nouveau type
                setTargetCase(targetSnapableCase)
            }
        }
    }

    ConnectionsConfigurationSection {
        id: connectionsConfigSection
        isCollapsed : true
        logic: panelContent.logic
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillWidth: true

        onRequestAddConnection: function(kind) {
            panelContent.connectionRequested(kind)
        }

    }


}
