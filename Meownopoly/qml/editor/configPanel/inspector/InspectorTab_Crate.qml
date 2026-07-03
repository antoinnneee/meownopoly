import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import crateConfigPanel

// Onglet « Caisse » : réutilise CrateConfigurationPanelSection tel quel.
ScrollView {
    id: root

    property var logic: null

    signal focusReleased()

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    contentWidth: availableWidth
    clip: true

    function setTarget(element) {
        crateSection.setTargetCrate(element && element.snapableParameters
                                    ? element.snapableParameters : null)
    }

    function clearTarget() {
        crateSection.setTargetCrate(null)
    }

    ColumnLayout {
        width: root.availableWidth

        CrateConfigurationPanelSection {
            id: crateSection
            Layout.fillWidth: true
            logic: root.logic
            isCollapsed: false
            onFocusReleased: root.focusReleased()
        }
    }
}
