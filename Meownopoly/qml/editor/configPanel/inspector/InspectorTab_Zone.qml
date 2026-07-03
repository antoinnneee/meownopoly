import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import zoneConfigPanel

// Onglet « Zone » : réutilise ZoneConfigurationPanelSection tel quel.
// Le signal configurationChanged de la section est relayé sous le nom
// zoneConfigurationChanged (contrat InspectorPanel → Editor.qml, qui applique
// getCurrentPhysicSettings() à toute la sélection).
ScrollView {
    id: root

    property var logic: null

    signal zoneConfigurationChanged()
    signal focusReleased()

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    contentWidth: availableWidth
    clip: true

    function setTarget(element) {
        const zoneParam = (element && element.snapableParameters)
                        ? element.snapableParameters.zoneParameter : null
        zoneSection.updatingValues = true
        zoneSection.updateFromZoneParameter(zoneParam)
        zoneSection.updatingValues = false
    }

    function clearTarget() {
    }

    // Même contrat que editorSidePanel.zoneConfigurationPanel — consommé par
    // le flush d'ops SetZoneParameter dans Editor.qml.
    function getCurrentPhysicSettings() {
        return zoneSection.getCurrentPhysicSettings()
    }

    ColumnLayout {
        width: root.availableWidth

        ZoneConfigurationPanelSection {
            id: zoneSection
            Layout.fillWidth: true
            logic: root.logic
            isCollapsed: false
            onConfigurationChanged: root.zoneConfigurationChanged()
            onFocusReleased: root.focusReleased()
        }
    }
}
