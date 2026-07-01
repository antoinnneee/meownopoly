import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AssetManager
import NPCParameter
import theme
import ui_item

/*
 * NCP_IdentitySection — nom + visuel du PNJ sélectionné.
 *
 * Mutations poussées vers le NPCParameter cible par le parent
 * (NPCConfigurationPanelSection) via le signal fieldEdited.
 */
ColumnLayout {
    id: root

    property bool updatingValues: false

    property alias npcName: nameInput.text
    property alias visualKind: visualKindCombo.currentIndex
    readonly property string modelName:
        visualKindCombo.currentIndex === NPCParameter.Model3D ? modelCombo.currentText : ""

    signal fieldEdited()

    spacing: Theme.spacingS

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Nom"
        MeowTextField {
            id: nameInput
            Layout.fillWidth: true
            placeholderText: "Nom du PNJ..."
            onEditingFinished: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Visuel"
        MeowComboBox {
            id: visualKindCombo
            Layout.fillWidth: true
            model: ["Modèle 3D", "Sprite 2D"]
            onActivated: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Modèle"
        visible: visualKindCombo.currentIndex === NPCParameter.Model3D
        MeowComboBox {
            id: modelCombo
            Layout.fillWidth: true
            model: AssetManager.availablePlayerModels()
            onActivated: if (!root.updatingValues) root.fieldEdited()
        }
    }

    function updateFromNpcParameter(npc) {
        if (!npc) return
        nameInput.text = npc.npcName
        visualKindCombo.currentIndex = npc.visualKind
        const idx = modelCombo.find(npc.modelName)
        modelCombo.currentIndex = idx >= 0 ? idx : 0
    }
}
