import QtQuick 2.15
import QtQuick.Layouts
import QtQuick.Controls

import meowComponent
import editor
import npcConfigPanel
import enemyConfigPanel

ColumnLayout {
    id: panelContent
    signal configurationChanged()
    signal effectChanged()
    signal connectionRequested(string kind)  // Propager les demandes de connexion
    signal modelSelected(string name)
    signal focusReleased()

    property var logic
    property alias effectsPanel: effectsPanel
    property alias caseConfigurationPanel: caseConfigurationPanelSection
    property alias connectionsConfigurationPanel: connectionsConfigSection
    property alias zoneConfigurationPanel: zoneConfigurationPanelSection
    property alias npcConfigurationPanel: npcConfigurationPanelSection
    property alias enemyConfigurationPanel: enemyConfigurationPanelSection
   // property alias transformSection: transformSection

    VisualEffectsPanel {
        id: effectsPanel
        isCollapsed : true
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillWidth: true

        onEffectChanged: {
            panelContent.effectChanged()
        }
    }

    ModelSelectionPanel {
        id: modelSelectionPanel
        isCollapsed: true
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        onModelSelected: function(name) {
            panelContent.modelSelected(name)
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

    // Onglet Configuration PNJ
    NPCConfigurationPanelSection {
        id: npcConfigurationPanelSection
        isCollapsed: true
        logic: panelContent.logic
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillWidth: true
        onFocusReleased: panelContent.focusReleased()
    }

    // Onglet Configuration Ennemi
    EnemyConfigurationPanelSection {
        id: enemyConfigurationPanelSection
        isCollapsed: true
        logic: panelContent.logic
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillWidth: true
        onFocusReleased: panelContent.focusReleased()
    }

    // Onglet Configuration Zone
    ZoneConfigurationPanelSection {
        id: zoneConfigurationPanelSection
        isCollapsed: true
        logic: panelContent.logic
        Layout.alignment: Qt.AlignLeft | Qt.AlignTop
        Layout.fillWidth: true
        onConfigurationChanged: {
            panelContent.configurationChanged()
        }
        onFocusReleased: {
            panelContent.focusReleased()
        }
    }


}
