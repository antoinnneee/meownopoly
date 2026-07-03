import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import caseConfigPanel

// Onglet « Économie » d'une case : réutilise les sections CCPS_* existantes
// (RestArea, Kibble, CardBoardBox, Device), affichées selon le type — même
// jeu de `visible:` que CaseConfigurationPanelSection. L'onglet n'est résolu
// par le registre que pour les 4 types qui ont une config économique.
ScrollView {
    id: root

    property var logic: null
    property var targetCase: null
    property bool updatingValues: false

    signal focusReleased()

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    contentWidth: availableWidth
    clip: true

    function setTarget(element) {
        if (!element || !element.snapableParameters
                || !element.snapableParameters.caseData) {
            clearTarget()
            return
        }
        targetCase = element.snapableParameters.caseData
        updatingValues = true
        if (targetCase.type === Case.CS_RestArea)
            restAreaSection.updateControls()
        else if (targetCase.type === Case.CS_KibbleDispenser)
            kibbleDispenserSection.updateControls()
        else if (targetCase.type === Case.CS_CardBoardBox)
            cardBoardBoxSection.updateControls()
        else if (targetCase.type === Case.CS_Device)
            catDeviceSection.updateControls()
        updatingValues = false
    }

    function clearTarget() {
        targetCase = null
    }

    ColumnLayout {
        width: root.availableWidth

        CCPS_RestAreaSection {
            id: restAreaSection
            Layout.fillWidth: true
            targetCase: root.targetCase
            updatingValues: root.updatingValues
            logic: root.logic
            isCollapsed: false
            visible: root.targetCase && root.targetCase.type === Case.CS_RestArea
        }

        CCPS_KibbleDispenserSection {
            id: kibbleDispenserSection
            Layout.fillWidth: true
            targetCase: root.targetCase
            updatingValues: root.updatingValues
            logic: root.logic
            isCollapsed: false
            visible: root.targetCase && root.targetCase.type === Case.CS_KibbleDispenser
        }

        CCPS_CardBoardBoxSection {
            id: cardBoardBoxSection
            Layout.fillWidth: true
            targetCase: root.targetCase
            updatingValues: root.updatingValues
            logic: root.logic
            isCollapsed: false
            visible: root.targetCase && root.targetCase.type === Case.CS_CardBoardBox
        }

        CCPS_CatDeviceSection {
            id: catDeviceSection
            Layout.fillWidth: true
            targetCase: root.targetCase
            updatingValues: root.updatingValues
            logic: root.logic
            isCollapsed: false
            visible: root.targetCase && root.targetCase.type === Case.CS_Device
        }
    }
}
