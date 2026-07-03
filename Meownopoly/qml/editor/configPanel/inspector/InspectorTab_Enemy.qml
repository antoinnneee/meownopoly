import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import enemyConfigPanel

// Onglet « Ennemi » : réutilise EnemyConfigurationPanelSection tel quel.
ScrollView {
    id: root

    property var logic: null

    signal focusReleased()

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    contentWidth: availableWidth
    clip: true

    function setTarget(element) {
        enemySection.setTargetEnemy(element && element.snapableParameters
                                    ? element.snapableParameters : null)
    }

    function clearTarget() {
        enemySection.setTargetEnemy(null)
    }

    ColumnLayout {
        width: root.availableWidth

        EnemyConfigurationPanelSection {
            id: enemySection
            Layout.fillWidth: true
            logic: root.logic
            isCollapsed: false
            onFocusReleased: root.focusReleased()
        }
    }
}
