/*
 * PlayerHealthHud — HUD fixe du joueur local : barre de vie + loot.
 * Tout l'état est lu dans les modules de gameplay (HealthModule,
 * CurrencyModule, InventoryModule) via le CombatController (stateRevision
 * re-déclenche l'évaluation à chaque changement).
 */
import QtQuick
import GameplayModuleManager 1.0
import theme

Item {
    id: root

    required property var combat

    readonly property var _health: GameplayModuleManager.healthModule
    readonly property var _currency: GameplayModuleManager.currencyModule
    readonly property var _inventory: GameplayModuleManager.inventoryModule

    // Actor local effectif (claim réseau ou joueur monoposte).
    readonly property string actorId: combat.localActorId

    readonly property int hp: {
        combat.stateRevision
        _health ? _health.hp(actorId) : 0
    }
    readonly property int maxHp: {
        combat.stateRevision
        _health ? _health.maxHp(actorId) : 1
    }
    readonly property real ratio: maxHp > 0 ? hp / maxHp : 0
    readonly property bool dead: hp <= 0

    // Loot : solde affiché seulement si le module monnaie est actif (il ne
    // s'active qu'au premier loot ou via la page modules).
    readonly property bool showCurrency: {
        combat.stateRevision
        _currency ? _currency.enabled : false
    }
    readonly property int balance: {
        combat.stateRevision
        _currency && _currency.enabled ? _currency.balance(actorId) : 0
    }
    readonly property bool showItems: {
        combat.stateRevision
        _inventory ? (_inventory.enabled && _inventory.totalItems(actorId) > 0) : false
    }
    readonly property int itemCount: {
        combat.stateRevision
        _inventory && _inventory.enabled ? _inventory.totalItems(actorId) : 0
    }

    visible: combat.active
    implicitWidth: Theme.px(220)
              + (showCurrency ? Theme.px(70) : 0)
              + (showItems ? Theme.px(60) : 0)
    implicitHeight: Theme.px(30)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusM
        color: Theme.panelSurface
        border.color: Theme.border
        border.width: 1
        opacity: 0.92
    }

    Row {
        anchors.fill: parent
        anchors.margins: Theme.spacingXS
        spacing: Theme.spacingXS

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.dead ? "💀" : "❤️"
            font.pixelSize: Theme.fontSizeBody
        }

        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.px(120)
            height: Theme.px(12)

            Rectangle {
                anchors.fill: parent
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.45)
            }
            Rectangle {
                x: 1; y: 1
                width: Math.max(0, (parent.width - 2) * Math.min(1, root.ratio))
                height: parent.height - 2
                radius: height / 2
                color: root.ratio > 0.5 ? "#4CAF50" : root.ratio > 0.25 ? "#FF9800" : "#F44336"
                Behavior on width { NumberAnimation { duration: 150 } }
            }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.hp + "/" + root.maxHp
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showCurrency
            text: "💰 " + root.balance
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showItems
            text: "🎒 " + root.itemCount
            color: Theme.textPrimary
            font.pixelSize: Theme.fontSizeSmall
            font.bold: true
        }
    }
}
