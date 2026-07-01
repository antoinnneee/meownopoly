import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import NPCParameter
import theme
import ui_item

/*
 * NCP_TriggerSection — mode de déclenchement + création/lien de la zone de
 * proximité (Phase 3). Le bouton demande au parent de créer une
 * PhysicZoneTile standard (exclusion=false → émet enter/exit) autour du PNJ
 * et de la lier (PNJ --next--> zone). La zone reste éditable avec l'outil
 * de zones existant.
 */
ColumnLayout {
    id: root

    property bool updatingValues: false
    property alias triggerMode: triggerCombo.currentIndex

    // Vrai si le PNJ cible a déjà une zone liée (renseigné par le parent).
    property bool hasLinkedZone: false

    signal fieldEdited()
    signal createZoneRequested()

    spacing: Theme.spacingS

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Mode"
        MeowComboBox {
            id: triggerCombo
            Layout.fillWidth: true
            model: ["Proximité", "Clic", "Toujours visible"]
            onActivated: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowButton {
        Layout.fillWidth: true
        Layout.preferredHeight: Theme.px(32)
        visible: triggerCombo.currentIndex === NPCParameter.Proximity
        iconText: "📡"
        text: root.hasLinkedZone ? "Zone de proximité liée ✓"
                                 : "Créer / lier la zone de proximité"
        variant: root.hasLinkedZone ? "success" : "primary"
        fontSize: Theme.fontSizeSmall
        hoverZoom: false
        glossy: false
        enabled: !root.hasLinkedZone
        onClicked: root.createZoneRequested()
    }

    MeowInfoBox {
        Layout.fillWidth: true
        visible: triggerCombo.currentIndex === NPCParameter.Proximity && root.hasLinkedZone
        text: "Déplacez/reshapez la zone avec l'outil de sélection standard — le lien est conservé."
    }

    function updateFromNpcParameter(npc) {
        if (!npc) return
        triggerCombo.currentIndex = npc.triggerMode
    }
}
