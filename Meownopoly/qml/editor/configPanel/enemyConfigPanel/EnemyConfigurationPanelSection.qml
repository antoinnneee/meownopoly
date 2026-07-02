import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Game
import EditDelta 1.0
import ItemSnapable
import EditorOpBus 1.0
import theme
import ui_item

/*
 * EnemyConfigurationPanelSection — panneau de config de l'ennemi sélectionné
 * (module "config", aux côtés de Case/Zone/PNJ). Sections ECP_* :
 * identité et statistiques de combat.
 *
 * Alimenté par BottomSidePanel.updateSidePanel (sélection simple d'une tile).
 * Chaque édition : mutation directe du EnemyParameter C++ → op
 * SetEnemyParameter (collab) + Game.updateMap(TileModified) débouncé
 * (persistance/undo).
 */
CollapsableGroupBox {
    id: root
    title: "Configuration d'ennemi"

    property bool updatingValues: false
    property var logic: null

    // ItemSnapable C++ de l'ennemi ciblé (null si sélection ≠ 1 ennemi).
    property var targetSnapable: null
    readonly property var targetEnemy: targetSnapable ? targetSnapable.enemyParameter : null

    signal focusReleased()

    // Renseigné par updateSidePanel : cible ou efface selon le tileType.
    function setTargetEnemy(snapableParameter) {
        if (snapableParameter && snapableParameter.tileType === ItemSnapable.EnemyTile) {
            targetSnapable = snapableParameter
            updatingValues = true
            identitySection.updateFromEnemyParameter(snapableParameter.enemyParameter)
            combatSection.updateFromEnemyParameter(snapableParameter.enemyParameter)
            updatingValues = false
        } else {
            targetSnapable = null
        }
    }

    // Commit débouncé : une rafale d'éditions (frappe, spinbox) ne produit
    // qu'un TileModified (persistance + ApplyState collab).
    Timer {
        id: commitDelayer
        interval: 200
        onTriggered: {
            if (!root.targetSnapable) return
            Game.updateMap(EditDelta.TileModified, root.targetSnapable)
        }
    }

    function _pushEnemyUpdate() {
        if (!targetSnapable || !targetEnemy || updatingValues) return
        EditorOpBus.recordOp(EditorOpBus.makeSetEnemyParameterOp(
            String(targetSnapable.uniqueId),
            JSON.parse(targetEnemy.toJSON())))
        commitDelayer.restart()
    }

    // Applique les champs des sections identité/combat dans le EnemyParameter.
    function _applyFormFields() {
        if (!targetEnemy || updatingValues) return
        targetEnemy.enemyName = identitySection.enemyName
        targetEnemy.modelName = identitySection.modelName
        targetEnemy.maxHp = combatSection.maxHp
        targetEnemy.attackDamage = combatSection.attackDamage
        targetEnemy.attackRange = combatSection.attackRange
        targetEnemy.attackCooldownMs = combatSection.attackCooldownMs
        targetEnemy.aggroRange = combatSection.aggroRange
        targetEnemy.moveSpeed = combatSection.moveSpeed
        targetEnemy.respawnEnabled = combatSection.respawnEnabled
        targetEnemy.respawnDelayMs = combatSection.respawnDelayMs
        _pushEnemyUpdate()
    }

    content: [
        Text {
            visible: root.targetSnapable === null
            text: "Sélectionnez un ennemi pour le configurer."
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
            font.italic: true
        },

        ECP_IdentitySection {
            id: identitySection
            visible: root.targetSnapable !== null
            Layout.fillWidth: true
            updatingValues: root.updatingValues
            onFieldEdited: root._applyFormFields()
        },

        ECP_CombatSection {
            id: combatSection
            visible: root.targetSnapable !== null
            Layout.fillWidth: true
            updatingValues: root.updatingValues
            onFieldEdited: root._applyFormFields()
        }
    ]
}
