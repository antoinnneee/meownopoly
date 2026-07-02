import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import AssetManager
import theme
import ui_item

/*
 * ECP_IdentitySection — nom + modèle 3D de l'ennemi sélectionné.
 *
 * Mutations poussées vers le EnemyParameter cible par le parent
 * (EnemyConfigurationPanelSection) via le signal fieldEdited.
 */
ColumnLayout {
    id: root

    property bool updatingValues: false

    property alias enemyName: nameInput.text
    readonly property string modelName: modelCombo.currentText

    signal fieldEdited()

    spacing: Theme.spacingS

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Nom"
        MeowTextField {
            id: nameInput
            Layout.fillWidth: true
            placeholderText: "Nom de l'ennemi..."
            onEditingFinished: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Modèle"
        MeowComboBox {
            id: modelCombo
            Layout.fillWidth: true
            model: AssetManager.availablePlayerModels()
            onActivated: if (!root.updatingValues) root.fieldEdited()
        }
    }

    function updateFromEnemyParameter(enemy) {
        if (!enemy) return
        nameInput.text = enemy.enemyName
        const idx = modelCombo.find(enemy.modelName)
        modelCombo.currentIndex = idx >= 0 ? idx : 0
    }
}
