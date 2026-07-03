import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import npcConfigPanel

// Onglet « PNJ » : réutilise NPCConfigurationPanelSection tel quel
// (la section prend le snapableParameters, pas l'élément, et fait son
// propre filtrage par tileType).
ScrollView {
    id: root

    property var logic: null

    signal focusReleased()

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    contentWidth: availableWidth
    clip: true

    function setTarget(element) {
        npcSection.setTargetNpc(element && element.snapableParameters
                                ? element.snapableParameters : null)
    }

    function clearTarget() {
        npcSection.setTargetNpc(null)
    }

    ColumnLayout {
        width: root.availableWidth

        NPCConfigurationPanelSection {
            id: npcSection
            Layout.fillWidth: true
            logic: root.logic
            isCollapsed: false
            onFocusReleased: root.focusReleased()
        }
    }
}
