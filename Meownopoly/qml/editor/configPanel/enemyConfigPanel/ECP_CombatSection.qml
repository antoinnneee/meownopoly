import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import theme
import ui_item

/*
 * ECP_CombatSection — statistiques de combat de l'ennemi sélectionné.
 *
 * Les portées/vitesse sont saisies en dixièmes de cellule (MeowSpinBox est
 * entier) : 12 → 1.2 cellules. Mutations poussées par le parent via fieldEdited.
 */
ColumnLayout {
    id: root

    property bool updatingValues: false

    readonly property int maxHp: maxHpSpin.value
    readonly property int attackDamage: damageSpin.value
    readonly property real attackRange: rangeSpin.value / 10.0
    readonly property int attackCooldownMs: cooldownSpin.value
    readonly property real aggroRange: aggroSpin.value / 10.0
    readonly property real moveSpeed: speedSpin.value / 10.0
    readonly property bool respawnEnabled: respawnCheck.checked
    readonly property int respawnDelayMs: respawnDelaySpin.value
    readonly property int lootCurrency: lootCurrencySpin.value
    readonly property string lootItemName: lootItemField.text
    readonly property int lootItemQuantity: lootQtySpin.value

    signal fieldEdited()

    spacing: Theme.spacingS

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Points de vie"
        MeowSpinBox {
            id: maxHpSpin
            Layout.fillWidth: true
            from: 1; to: 9999; value: 30
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Dégâts"
        MeowSpinBox {
            id: damageSpin
            Layout.fillWidth: true
            from: 0; to: 999; value: 5
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Portée (×0.1)"
        MeowSpinBox {
            id: rangeSpin
            Layout.fillWidth: true
            from: 1; to: 200; value: 12
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Cooldown (ms)"
        MeowSpinBox {
            id: cooldownSpin
            Layout.fillWidth: true
            from: 100; to: 10000; stepSize: 100; value: 1000
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Aggro (×0.1)"
        MeowSpinBox {
            id: aggroSpin
            Layout.fillWidth: true
            from: 0; to: 500; value: 40
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Vitesse (×0.1)"
        MeowSpinBox {
            id: speedSpin
            Layout.fillWidth: true
            from: 0; to: 200; value: 20
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Respawn"
        MeowCheckBox {
            id: respawnCheck
            onCheckedChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Délai respawn (ms)"
        visible: respawnCheck.checked
        MeowSpinBox {
            id: respawnDelaySpin
            Layout.fillWidth: true
            from: 500; to: 60000; stepSize: 500; value: 5000
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    // ── Loot à la mort (modules monnaie / inventaire) ──────────────────────
    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Loot monnaie"
        MeowSpinBox {
            id: lootCurrencySpin
            Layout.fillWidth: true
            from: 0; to: 99999; stepSize: 5; value: 0
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Loot objet"
        MeowTextField {
            id: lootItemField
            Layout.fillWidth: true
            placeholderText: "Nom d'objet (vide = aucun)..."
            onEditingFinished: if (!root.updatingValues) root.fieldEdited()
        }
    }

    MeowPropertyRow {
        Layout.fillWidth: true
        label: "Quantité objet"
        visible: lootItemField.text !== ""
        MeowSpinBox {
            id: lootQtySpin
            Layout.fillWidth: true
            from: 1; to: 99; value: 1
            onValueChanged: if (!root.updatingValues) root.fieldEdited()
        }
    }

    function updateFromEnemyParameter(enemy) {
        if (!enemy) return
        maxHpSpin.value = enemy.maxHp
        damageSpin.value = enemy.attackDamage
        rangeSpin.value = Math.round(enemy.attackRange * 10)
        cooldownSpin.value = enemy.attackCooldownMs
        aggroSpin.value = Math.round(enemy.aggroRange * 10)
        speedSpin.value = Math.round(enemy.moveSpeed * 10)
        respawnCheck.checked = enemy.respawnEnabled
        respawnDelaySpin.value = enemy.respawnDelayMs
        lootCurrencySpin.value = enemy.lootCurrency
        lootItemField.text = enemy.lootItemName
        lootQtySpin.value = enemy.lootItemQuantity
    }
}
