import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowMemory 1.0
import Game 1.0
import theme

// Panneau de test interactif — état runtime + mémoire + transactions.
//   - écriture/lecture live d'une valeur mémoire (scope tile/session/player) via
//     MemoryStore (session/joueur) ou StateBus (tuile, transport D35) ;
//   - compteurs StateBus (deltasSent/Received, snapshots, divergences D39) ;
//   - bloc Transactions : begin/prepare/commit/rollback via Game (M4/T3-1) avec
//     affichage du résultat et démonstration du rollback (valeur restaurée par
//     compensation pilotée par le signal transactionRolledBack).
Rectangle {
    id: root
    required property var host

    property string _readback: "—"
    property int _divergences: 0
    property string _txId: ""
    property string _txResult: ""
    // Démo rollback : valeur mémoire de référence à restaurer sur annulation.
    property string _txDemoKey: "tx_demo"
    property string _txDemoBaseline: ""
    property bool _txDemoArmed: false
    property string _txDemoTrace: ""

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: content.implicitHeight + Theme.spacingXXL * 2

    // 0 = session, 1 = player, 2 = tile.
    function _writeValue() {
        const key = keyField.text;
        const val = valueField.text;
        const idx = scopeCombo.currentIndex;
        if (idx === 0)
            MemoryStore.setSessionValue(key, val);
        else if (idx === 1)
            MemoryStore.setPlayerValue(playerIdField.text || "p1", key, val);
        else
            StateBus.submitWrite("tile:" + (playerIdField.text || "t1"), key, val);
        root._readValue();
    }

    function _readValue() {
        const key = keyField.text;
        const idx = scopeCombo.currentIndex;
        let v;
        if (idx === 0)
            v = MemoryStore.sessionValue(key);
        else if (idx === 1)
            v = MemoryStore.playerValue(playerIdField.text || "p1", key);
        else
            v = StateBus.value("tile:" + (playerIdField.text || "t1"), key);
        root._readback = (v === undefined || v === null) ? "∅" : ("" + v);
    }

    // ── Démo transaction + rollback (valeur restaurée) ───────────────────────
    function _txBegin() {
        root._txId = "" + Game.beginTransaction();
        root._txResult = "begin";
    }
    function _txPrepare() {
        // prepare avec un lot vide : prévalidation triviale (aucune op invalide).
        // Sur une map chargée, `ops` porterait des { type, tileId, before, after }.
        const id = "" + Game.prepareTransaction([]);
        root._txId = id;
        root._txResult = (id && id.indexOf("0000000") !== 0) ? "prepare ok" : "prepare refusé (pas de map)";
    }
    function _txCommit() {
        const ok = Game.commitTransaction();
        root._txResult = "commit → " + ok;
    }
    function _txRollback() {
        Game.rollbackTransaction();
        root._txResult = "rollback demandé";
    }

    function _txDemoRun() {
        // 1) valeur de référence en mémoire session.
        root._txDemoBaseline = "baseline-" + Date.now().toString().slice(-4);
        MemoryStore.setSessionValue(root._txDemoKey, root._txDemoBaseline);
        // 2) ouvre une transaction et arme la compensation.
        root._txId = "" + Game.beginTransaction();
        root._txDemoArmed = true;
        // 3) mutation « dans la transaction ».
        MemoryStore.setSessionValue(root._txDemoKey, "muté-dans-tx");
        root._txDemoTrace = "baseline=" + root._txDemoBaseline
                          + " · muté → " + MemoryStore.sessionValue(root._txDemoKey);
        // 4) annule : transactionRolledBack déclenche la restauration (compensation).
        Game.rollbackTransaction();
    }

    Connections {
        target: Game
        function onTransactionRolledBack(txId, reason) {
            if (root._txDemoArmed) {
                // Compensation : la mémoire n'est pas dans la Map M4 ; le panneau
                // restaure la valeur de référence à la réception du signal.
                MemoryStore.setSessionValue(root._txDemoKey, root._txDemoBaseline);
                root._txDemoArmed = false;
                root._txDemoTrace += " · rollback → restauré = "
                                   + MemoryStore.sessionValue(root._txDemoKey);
            }
            root._txResult = "rolledBack (" + reason + ")";
        }
        function onTransactionCommitted(txId) {
            root._txResult = "committed";
        }
    }

    Connections {
        target: StateBus
        function onDivergenceDetected(hostHash, localHash) {
            root._divergences += 1;
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM

        Text {
            text: "État runtime + mémoire"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "MeowMemory · StateBus + MemoryStore · transactions Game (M4)"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }

        // ── Écriture / lecture mémoire ───────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS

            ComboBox {
                id: scopeCombo
                objectName: "memoryScopeCombo"
                Layout.preferredWidth: Theme.px(96)
                font.pixelSize: Theme.fontSizeSmall
                model: ["session", "player", "tile"]
                onCurrentIndexChanged: root._readValue()
            }
            TextField {
                id: playerIdField
                objectName: "memoryScopeIdField"
                visible: scopeCombo.currentIndex !== 0
                Layout.preferredWidth: Theme.px(72)
                text: "p1"
                placeholderText: scopeCombo.currentIndex === 2 ? "tileId" : "playerId"
                font.pixelSize: Theme.fontSizeSmall
                color: root.host.textPrimary
                background: Rectangle { color: Theme.background; radius: Theme.radiusM; border.color: root.host.cardBorder; border.width: 1 }
            }
            TextField {
                id: keyField
                objectName: "memoryKeyField"
                Layout.preferredWidth: Theme.px(80)
                text: "score"
                placeholderText: "clé"
                font.pixelSize: Theme.fontSizeSmall
                color: root.host.textPrimary
                background: Rectangle { color: Theme.background; radius: Theme.radiusM; border.color: root.host.cardBorder; border.width: 1 }
            }
            TextField {
                id: valueField
                objectName: "memoryValueField"
                Layout.fillWidth: true
                text: "42"
                placeholderText: "valeur"
                font.pixelSize: Theme.fontSizeSmall
                color: root.host.textPrimary
                background: Rectangle { color: Theme.background; radius: Theme.radiusM; border.color: root.host.cardBorder; border.width: 1 }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            Button {
                objectName: "memoryWriteButton"
                text: "écrire"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._writeValue()
            }
            Button {
                objectName: "memoryReadButton"
                text: "relire"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._readValue()
            }
            Text {
                text: "valeur lue : "
                color: root.host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                Layout.alignment: Qt.AlignVCenter
            }
            Text {
                objectName: "memoryReadbackLabel"
                text: root._readback
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
                font.family: "Consolas"
                Layout.fillWidth: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }

        // ── Compteurs StateBus ───────────────────────────────────────────────
        GridLayout {
            columns: 4
            columnSpacing: Theme.spacingL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            Text { text: "deltasSent"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.deltasSent; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "deltasReceived"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.deltasReceived; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "snapshotsSent"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.snapshotsSent; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "snapshotsRecv"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.snapshotsReceived; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "rejectsEmitted"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.rejectsEmitted; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "divergences D39"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                objectName: "divergenceCountLabel"
                text: "" + root._divergences
                color: root._divergences > 0 ? Theme.danger : root.host.textPrimary
                font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }

        // ── Transactions ─────────────────────────────────────────────────────
        Text {
            text: "Transactions atomiques (M4)"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            Button { objectName: "txBeginButton"; text: "begin"; font.pixelSize: Theme.fontSizeSmall; onClicked: root._txBegin() }
            Button { objectName: "txPrepareButton"; text: "prepare"; font.pixelSize: Theme.fontSizeSmall; onClicked: root._txPrepare() }
            Button { objectName: "txCommitButton"; text: "commit"; font.pixelSize: Theme.fontSizeSmall; onClicked: root._txCommit() }
            Button { objectName: "txRollbackButton"; text: "rollback"; font.pixelSize: Theme.fontSizeSmall; onClicked: root._txRollback() }
        }
        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            Text { text: "txId"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                objectName: "txIdLabel"
                text: root._txId ? root._txId.substring(0, 20) + "…" : "—"
                color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
                Layout.fillWidth: true; elide: Text.ElideRight
            }
            Text { text: "résultat"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                objectName: "txResultLabel"
                text: root._txResult || "—"
                color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.bold: true; font.family: "Consolas"
            }
        }

        // Démonstration rollback → valeur restaurée.
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM
            Button {
                objectName: "txDemoRollbackButton"
                text: "Démo rollback (valeur restaurée)"
                font.pixelSize: Theme.fontSizeSmall
                onClicked: root._txDemoRun()
            }
        }
        Text {
            objectName: "txDemoTraceLabel"
            visible: root._txDemoTrace !== ""
            text: root._txDemoTrace
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.family: "Consolas"
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
