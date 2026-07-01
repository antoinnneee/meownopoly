import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import theme
import ui_item
import GameplayModuleManager 1.0

/*
 * GameplayModulesTestPage — banc d'essai des modules de gameplay activables
 * (vie, inventaire, monnaie). Remplace l'ancien "Test Component".
 *
 * Chaque section pilote un module du singleton GameplayModuleManager :
 *  - un switch d'activation bindé sur module.enabled ;
 *  - des contrôles de test opérant sur un playerId saisissable ;
 *  - un log d'événements commun alimenté par les signaux des modules.
 */
Rectangle {
    id: root
    color: Theme.background

    // Remonté à main.qml pour dépiler la page.
    signal backRequested()

    // ── Références aux modules ───────────────────────────────────────────
    readonly property var _health: GameplayModuleManager.healthModule
    readonly property var _inventory: GameplayModuleManager.inventoryModule
    readonly property var _currency: GameplayModuleManager.currencyModule

    // ── Joueurs de test ──────────────────────────────────────────────────
    property string _playerA: "Princess"
    property string _playerB: "Whiskers"

    // ── État miroir (rafraîchi via les signaux des modules) ──────────────
    property int _hp: 0
    property int _maxHp: 0
    property bool _dead: false
    property int _balanceA: 0
    property int _balanceB: 0

    // ── Log d'événements commun ──────────────────────────────────────────
    function _log(line) {
        const now = Qt.formatTime(new Date(), "HH:mm:ss")
        eventLog.insert(0, { "line": "[" + now + "] " + line })
        while (eventLog.count > 200)
            eventLog.remove(eventLog.count - 1)
    }

    function _refreshHealth() {
        root._hp = root._health.hp(root._playerA)
        root._maxHp = root._health.maxHp(root._playerA)
        root._dead = root._health.isDead(root._playerA)
    }
    function _refreshInventory() {
        inventoryModel.clear()
        const list = root._inventory.items(root._playerA)
        for (let i = 0; i < list.length; ++i)
            inventoryModel.append(list[i])
    }
    function _refreshCurrency() {
        root._balanceA = root._currency.balance(root._playerA)
        root._balanceB = root._currency.balance(root._playerB)
    }

    Component.onCompleted: {
        _refreshHealth()
        _refreshInventory()
        _refreshCurrency()
    }

    // ── Connexions aux signaux des modules ───────────────────────────────
    Connections {
        target: root._health
        function onHealthChanged(playerId, hp, maxHp) {
            root._log("❤️ " + playerId + " PV = " + hp + "/" + maxHp)
            if (playerId === root._playerA) root._refreshHealth()
        }
        function onPlayerDied(playerId) {
            root._log("💀 " + playerId + " est KO")
            if (playerId === root._playerA) root._refreshHealth()
        }
        function onPlayerRevived(playerId) {
            root._log("✨ " + playerId + " est ranimé")
            if (playerId === root._playerA) root._refreshHealth()
        }
    }
    Connections {
        target: root._inventory
        function onItemAdded(playerId, itemName, quantity, newQuantity) {
            root._log("🎒 +" + quantity + " " + itemName + " → " + playerId
                      + " (total item: " + newQuantity + ")")
        }
        function onItemRemoved(playerId, itemName, quantity, newQuantity) {
            root._log("🎒 -" + quantity + " " + itemName + " ← " + playerId
                      + " (reste: " + newQuantity + ")")
        }
        function onInventoryChanged(playerId) {
            if (playerId === root._playerA) root._refreshInventory()
        }
        function onCapacityExceeded(playerId, itemName, requested) {
            root._log("⛔ Capacité dépassée : +" + requested + " " + itemName
                      + " refusé pour " + playerId)
        }
    }
    Connections {
        target: root._currency
        function onBalanceChanged(playerId, balance) {
            root._log("💰 " + playerId + " solde = " + balance)
            if (playerId === root._playerA || playerId === root._playerB)
                root._refreshCurrency()
        }
        function onTransferFailed(fromId, toId, amount, reason) {
            root._log("⛔ Opération refusée (" + reason + ") : " + amount
                      + " de " + fromId + (toId.length > 0 ? " → " + toId : ""))
        }
    }

    // ── En-tête ──────────────────────────────────────────────────────────
    MeowButton {
        id: backButton
        objectName: "gameplayModulesBackButton"
        iconText: "←"
        text: "Retour"
        variant: "secondary"
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Theme.spacingL
        z: 100
        onClicked: root.backRequested()
    }

    Text {
        id: pageTitle
        text: "🧩 Modules Gameplay"
        color: Theme.textPrimary
        font.pixelSize: Theme.fontSizeHeading
        font.bold: true
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Theme.spacingXXL
    }

    // ── Corps : sections + log ───────────────────────────────────────────
    RowLayout {
        anchors.top: backButton.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spacingXXL
        anchors.topMargin: Theme.spacingL
        spacing: Theme.spacingXXL

        // Colonne des modules (scrollable)
        ScrollView {
            id: modulesScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                width: modulesScroll.availableWidth
                spacing: Theme.spacingXXL

                // ═══ Section identités de test ═══
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: idCol.implicitHeight + 2 * Theme.spacingL
                    color: Theme.surface
                    radius: Theme.radiusM
                    border.color: Theme.border

                    ColumnLayout {
                        id: idCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingM

                        Text {
                            text: "Joueurs de test"
                            color: Theme.textPrimary
                            font.pixelSize: Theme.fontSizeMedium
                            font.bold: true
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingL
                            Text {
                                text: "Joueur A"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeBody
                            }
                            MeowTextField {
                                Layout.preferredWidth: 140
                                text: root._playerA
                                onEditingFinished: {
                                    root._playerA = text
                                    root._refreshHealth()
                                    root._refreshInventory()
                                    root._refreshCurrency()
                                }
                            }
                            Text {
                                text: "Joueur B"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeBody
                            }
                            MeowTextField {
                                Layout.preferredWidth: 140
                                text: root._playerB
                                onEditingFinished: {
                                    root._playerB = text
                                    root._refreshCurrency()
                                }
                            }
                        }
                    }
                }

                // ═══ Module de vie ═══
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: healthCol.implicitHeight + 2 * Theme.spacingL
                    color: Theme.surface
                    radius: Theme.radiusM
                    border.color: Theme.border

                    ColumnLayout {
                        id: healthCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingM

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root._health.name
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            MeowSwitch {
                                checked: root._health.enabled
                                onToggled: root._health.enabled = checked
                            }
                        }

                        // Barre de PV
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 24
                            opacity: root._health.enabled ? 1.0 : 0.5

                            Rectangle {
                                anchors.fill: parent
                                radius: Theme.radiusS
                                color: Theme.background
                                border.color: Theme.border

                                Rectangle {
                                    height: parent.height - 4
                                    y: 2; x: 2
                                    width: (parent.width - 4)
                                           * (root._maxHp > 0 ? Math.max(0, root._hp) / root._maxHp : 0)
                                    radius: Theme.radiusS
                                    color: root._dead ? Theme.danger
                                         : (root._hp < root._maxHp * 0.3 ? Theme.warning : Theme.success)
                                    Behavior on width { NumberAnimation { duration: Theme.durationNormal } }
                                }
                                Text {
                                    anchors.centerIn: parent
                                    text: root._dead ? ("KO — " + root._playerA)
                                                     : (root._hp + " / " + root._maxHp)
                                    color: Theme.textPrimary
                                    font.pixelSize: Theme.fontSizeBody
                                    font.bold: true
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM
                            enabled: root._health.enabled

                            MeowButton {
                                text: "-20"; variant: "danger"; fontSize: Theme.fontSizeBody
                                onClicked: root._health.damage(root._playerA, 20)
                            }
                            MeowButton {
                                text: "-5"; variant: "danger"; fontSize: Theme.fontSizeBody
                                onClicked: root._health.damage(root._playerA, 5)
                            }
                            MeowButton {
                                text: "+5"; variant: "success"; fontSize: Theme.fontSizeBody
                                onClicked: root._health.heal(root._playerA, 5)
                            }
                            MeowButton {
                                text: "+20"; variant: "success"; fontSize: Theme.fontSizeBody
                                onClicked: root._health.heal(root._playerA, 20)
                            }
                            Item { Layout.fillWidth: true }
                            MeowButton {
                                text: "Ranimer"; variant: "secondary"; fontSize: Theme.fontSizeBody
                                onClicked: root._health.revive(root._playerA)
                            }
                            MeowButton {
                                text: "Reset"; variant: "secondary"; fontSize: Theme.fontSizeBody
                                onClicked: { root._health.reset(); root._refreshHealth() }
                            }
                        }
                    }
                }

                // ═══ Module d'inventaire ═══
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: invCol.implicitHeight + 2 * Theme.spacingL
                    color: Theme.surface
                    radius: Theme.radiusM
                    border.color: Theme.border

                    ColumnLayout {
                        id: invCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingM

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root._inventory.name
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            MeowSwitch {
                                checked: root._inventory.enabled
                                onToggled: root._inventory.enabled = checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM
                            enabled: root._inventory.enabled

                            MeowTextField {
                                id: itemNameField
                                Layout.fillWidth: true
                                placeholderText: "Nom de l'objet"
                                text: "Croquette"
                            }
                            Text {
                                text: "Qté"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeBody
                            }
                            MeowSpinBox {
                                id: itemQtySpin
                                Layout.preferredWidth: 110
                                from: 1; to: 999; value: 1; suffix: ""
                            }
                            MeowButton {
                                text: "Ajouter"; variant: "success"; fontSize: Theme.fontSizeBody
                                onClicked: root._inventory.addItem(root._playerA,
                                                                   itemNameField.text,
                                                                   itemQtySpin.value)
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 160
                            color: Theme.background
                            radius: Theme.radiusS
                            border.color: Theme.border

                            ListView {
                                id: inventoryList
                                anchors.fill: parent
                                anchors.margins: Theme.spacingS
                                clip: true
                                spacing: Theme.spacingXS
                                model: ListModel { id: inventoryModel }

                                delegate: RowLayout {
                                    id: invRow
                                    width: inventoryList.width
                                    spacing: Theme.spacingM
                                    required property string name
                                    required property int quantity

                                    Text {
                                        text: invRow.name
                                        color: Theme.textPrimary
                                        font.pixelSize: Theme.fontSizeBody
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: "×" + invRow.quantity
                                        color: Theme.textSecondary
                                        font.pixelSize: Theme.fontSizeBody
                                        font.bold: true
                                    }
                                    MeowButton {
                                        text: "-1"; variant: "danger"; fontSize: Theme.fontSizeCaption
                                        enabled: root._inventory.enabled
                                        onClicked: root._inventory.removeItem(root._playerA,
                                                                              invRow.name, 1)
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    visible: inventoryModel.count === 0
                                    text: "Inventaire vide"
                                    color: Theme.textMuted
                                    font.pixelSize: Theme.fontSizeBody
                                    font.italic: true
                                }
                            }
                        }
                    }
                }

                // ═══ Module de monnaie ═══
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: curCol.implicitHeight + 2 * Theme.spacingL
                    color: Theme.surface
                    radius: Theme.radiusM
                    border.color: Theme.border

                    ColumnLayout {
                        id: curCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingL
                        spacing: Theme.spacingM

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: root._currency.name
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeTitle
                                font.bold: true
                                Layout.fillWidth: true
                            }
                            MeowSwitch {
                                checked: root._currency.enabled
                                onToggled: root._currency.enabled = checked
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingHuge
                            Text {
                                text: root._playerA + " : " + root._balanceA + " 🪙"
                                color: Theme.textPrimary
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                            }
                            Text {
                                text: root._playerB + " : " + root._balanceB + " 🪙"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeMedium
                                font.bold: true
                            }
                            Item { Layout.fillWidth: true }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.spacingM
                            enabled: root._currency.enabled

                            Text {
                                text: "Montant"
                                color: Theme.textSecondary
                                font.pixelSize: Theme.fontSizeBody
                            }
                            MeowSpinBox {
                                id: amountSpin
                                Layout.preferredWidth: 140
                                from: 1; to: 99999; value: 100; stepSize: 50; suffix: ""
                            }
                            MeowButton {
                                text: "Créditer A"; variant: "success"; fontSize: Theme.fontSizeBody
                                onClicked: root._currency.credit(root._playerA, amountSpin.value)
                            }
                            MeowButton {
                                text: "Débiter A"; variant: "warning"; fontSize: Theme.fontSizeBody
                                onClicked: root._currency.debit(root._playerA, amountSpin.value)
                            }
                            MeowButton {
                                text: "A → B"; variant: "primary"; fontSize: Theme.fontSizeBody
                                onClicked: root._currency.transfer(root._playerA, root._playerB,
                                                                   amountSpin.value)
                            }
                            Item { Layout.fillWidth: true }
                            MeowButton {
                                text: "Reset"; variant: "secondary"; fontSize: Theme.fontSizeBody
                                onClicked: { root._currency.reset(); root._refreshCurrency() }
                            }
                        }
                    }
                }
            }
        }

        // ── Colonne du log d'événements ──────────────────────────────────
        Rectangle {
            Layout.preferredWidth: 360
            Layout.fillHeight: true
            color: Theme.surface
            radius: Theme.radiusM
            border.color: Theme.border

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingM

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "Journal des événements"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeMedium
                        font.bold: true
                        Layout.fillWidth: true
                    }
                    MeowButton {
                        text: "Vider"; variant: "secondary"; fontSize: Theme.fontSizeCaption
                        onClicked: eventLog.clear()
                    }
                }

                ListView {
                    id: logView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: Theme.spacingXXS
                    model: ListModel { id: eventLog }
                    delegate: Text {
                        required property string line
                        width: logView.width
                        text: line
                        color: Theme.textSoft
                        font.pixelSize: Theme.fontSizeCaption
                        font.family: "monospace"
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }
        }
    }
}
