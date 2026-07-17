import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ProposalSession 1.0
import MeowProposal 1.0
import EditorOpBus 1.0
import theme

// Panneau de test interactif — pipeline de PROPOSITION (doc v3 13).
//   - soumission d'une enveloppe de test via ProposalLifecycle.submit (S-1) ;
//   - cycle de vie live (draft → … → applied) avec état coloré + journal des
//     transitions (proposalStateChanged) ;
//   - verdict à deux audiences (provideVerdictDoc → reasons player/ai) ;
//   - file `queued` (arbitre indisponible, D31) ;
//   - undo/redo ciblé de proposition (EditorOpBus.undo/redoProposal, D28) ;
//   - état du transport ProposalSession (isHost/busy/pendingCount).
Rectangle {
    id: root
    required property var host

    // Dernière proposition soumise (objet Proposal, uncreatable QML).
    property var _lastProposal: null
    property string _lastId: ""
    property string _lastState: ""
    property string _lastRequestType: ""
    property var _verdict: null            // QVariantMap verdict (2 audiences)
    property string _revertResult: ""      // trace undo/redoProposal

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: content.implicitHeight + Theme.spacingXXL * 2

    // Couleur sémantique d'un état du cycle de vie.
    function _stateColor(s) {
        if (s === "applied" || s === "validated")
            return Theme.success;
        if (s === "arbitrating" || s === "benching" || s === "amended" || s === "queued")
            return Theme.warning;
        if (s.indexOf("rejected") === 0 || s === "failed")
            return Theme.danger;
        return root.host.textPrimary;
    }

    function _submit() {
        const t = typeCombo.currentIndex;
        const env = {
            envelopeVersion: 1,
            channelVersion: "1.0.0",
            author: { playerId: authorField.text || "tester", role: "proposer" },
            intent: {
                playerPrompt: promptField.text,
                aiSummary: "test harness · " + typeCombo.currentText
            },
            operations: [],
            artifacts: []
        };
        if (t === 0) {
            env.operations.push({ op: "memory_set", scope: "session",
                                  key: "score", value: 1 });
        } else if (t === 1) {
            env.operations.push({ op: "editor_edit", subop: "delete",
                                  uuid: "tile-test" });
        } else if (t === 2) {
            env.operations.push({ op: "rules_edit", note: "test rule change" });
        } else {
            env.artifacts.push({ contentHash: "sha256:testartifact",
                                 source: artifactField.text || "Item { }",
                                 declaredWriteSet: ["session/score"] });
        }
        const p = ProposalLifecycle.submit(env);
        root._lastProposal = p;
        root._lastId = p ? p.proposalId : "";
        root._lastState = p ? p.state : "";
        root._lastRequestType = p ? p.requestType : "";
        root._verdict = null;
        root._revertResult = "";
        historyModel.clear();
        if (p) {
            const h = p.history();
            for (let i = 0; i < h.length; ++i) {
                historyModel.append({ line: (h[i].from || "∅") + " → " + h[i].to
                                            + (h[i].code ? "  [" + h[i].code + "]" : "") });
            }
        }
    }

    function _sendVerdict(outcome) {
        if (!root._lastId)
            return;
        const vJson = {
            verdict: outcome,
            reasons: [
                { audience: "player",
                  text: outcome === "accepted" ? "Proposition validée par l'arbitre."
                      : outcome === "amended" ? "Proposition amendée avant application."
                      : "Proposition refusée par l'arbitre." },
                { audience: "ai",
                  code: outcome === "accepted" ? "ok" : outcome,
                  text: outcome === "rejected" ? "Corrige puis re-propose."
                      : "Applique le patch tel quel.",
                  retryable: outcome === "rejected" }
            ]
        };
        const ok = ProposalLifecycle.provideVerdictDoc(root._lastId, vJson, "arbiter");
        if (ok && root._lastProposal) {
            const m = root._lastProposal.toVariantMap();
            root._verdict = m.verdict || null;
        }
    }

    function _reason(audience) {
        if (!root._verdict || !root._verdict.reasons)
            return "—";
        const rs = root._verdict.reasons;
        for (let i = 0; i < rs.length; ++i) {
            if (rs[i].audience === audience)
                return rs[i].text + (rs[i].code ? "  [" + rs[i].code + "]" : "");
        }
        return "—";
    }

    // Relais live des transitions vers le journal + les propriétés miroir.
    Connections {
        target: ProposalLifecycle
        function onProposalStateChanged(proposalId, state) {
            if (proposalId !== root._lastId)
                return;
            historyModel.append({ line: "→ " + state });
            root._lastState = state;
        }
        function onProposalVerdictReady(proposalId) {
            if (proposalId === root._lastId && root._lastProposal) {
                const m = root._lastProposal.toVariantMap();
                root._verdict = m.verdict || null;
            }
        }
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM

        Text {
            text: "Pipeline proposition"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "MeowProposal · ProposalLifecycle (S-1) + ProposalSession (T3-2)"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }

        // ── Formulaire de soumission ─────────────────────────────────────────
        Text {
            text: "Auteur simulé"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
        TextField {
            id: authorField
            objectName: "proposalAuthorField"
            Layout.fillWidth: true
            text: "tester"
            placeholderText: "playerId auteur"
            font.pixelSize: Theme.fontSizeBody
            color: root.host.textPrimary
            background: Rectangle {
                color: Theme.background
                radius: Theme.radiusM
                border.color: root.host.cardBorder
                border.width: 1
            }
        }

        Text {
            text: "Type d'opération (→ requestType recalculé par le P0)"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
        ComboBox {
            id: typeCombo
            objectName: "proposalTypeCombo"
            Layout.fillWidth: true
            font.pixelSize: Theme.fontSizeBody
            model: ["memory_set (data_safe)", "editor delete (structure)",
                    "rules_edit (rules → arbitre)", "artefact QML (code → arbitre)"]
        }

        TextField {
            id: artifactField
            objectName: "proposalArtifactField"
            visible: typeCombo.currentIndex === 3
            Layout.fillWidth: true
            placeholderText: "source QML artefact (optionnel)"
            text: "Item { }"
            font.pixelSize: Theme.fontSizeBody
            color: root.host.textPrimary
            background: Rectangle {
                color: Theme.background
                radius: Theme.radiusM
                border.color: root.host.cardBorder
                border.width: 1
            }
        }

        TextField {
            id: promptField
            objectName: "proposalPromptField"
            Layout.fillWidth: true
            placeholderText: "intent.playerPrompt (texte joueur)"
            text: "Pose une tour ici"
            font.pixelSize: Theme.fontSizeBody
            color: root.host.textPrimary
            background: Rectangle {
                color: Theme.background
                radius: Theme.radiusM
                border.color: root.host.cardBorder
                border.width: 1
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            Button {
                objectName: "proposalSubmitButton"
                text: "Soumettre"
                font.pixelSize: Theme.fontSizeBody
                onClicked: root._submit()
            }
            Item { Layout.fillWidth: true }
            Text {
                text: "arbitre dispo"
                color: root.host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
            }
            Switch {
                objectName: "arbiterAvailableSwitch"
                checked: ProposalLifecycle.arbiterAvailable
                onToggled: ProposalLifecycle.arbiterAvailable = checked
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }

        // ── Cycle de vie de la dernière proposition ──────────────────────────
        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            Text { text: "proposalId"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                objectName: "proposalIdLabel"
                text: root._lastId ? root._lastId.substring(0, 18) + "…" : "—"
                color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
                Layout.fillWidth: true; elide: Text.ElideRight
            }

            Text { text: "requestType"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: root._lastRequestType || "—"; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "état"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                objectName: "proposalStateLabel"
                text: root._lastState || "—"
                color: root._stateColor(root._lastState)
                font.pixelSize: Theme.fontSizeSmall; font.bold: true; font.family: "Consolas"
            }
        }

        // Boutons de verdict (actifs si en arbitrage).
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            enabled: root._lastState === "arbitrating"
            opacity: enabled ? 1.0 : 0.4

            Text {
                text: "verdict :"
                color: root.host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                Layout.alignment: Qt.AlignVCenter
            }
            Button {
                objectName: "verdictAcceptButton"
                text: "accepter"; font.pixelSize: Theme.fontSizeSmall
                onClicked: root._sendVerdict("accepted")
            }
            Button {
                objectName: "verdictAmendButton"
                text: "amender"; font.pixelSize: Theme.fontSizeSmall
                onClicked: root._sendVerdict("amended")
            }
            Button {
                objectName: "verdictRejectButton"
                text: "rejeter"; font.pixelSize: Theme.fontSizeSmall
                onClicked: root._sendVerdict("rejected")
            }
        }

        // Raisons du verdict (2 audiences).
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXXS
            visible: root._verdict !== null

            Text {
                text: "reason(player) : " + root._reason("player")
                color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall
                Layout.fillWidth: true; wrapMode: Text.WordWrap
            }
            Text {
                text: "reason(ai) : " + root._reason("ai")
                color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall
                Layout.fillWidth: true; wrapMode: Text.WordWrap
            }
        }

        // Journal des transitions.
        Text {
            text: "Transitions (journal live)"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeSmall
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Theme.px(96)
            color: Theme.background
            radius: Theme.radiusM
            border.color: root.host.cardBorder
            border.width: 1
            clip: true

            ListView {
                id: historyView
                objectName: "proposalHistoryList"
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                model: ListModel { id: historyModel }
                delegate: Text {
                    required property string line
                    width: historyView.width
                    text: line
                    color: root.host.textPrimary
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: "Consolas"
                    elide: Text.ElideRight
                }
                onCountChanged: positionViewAtEnd()
            }
        }

        // ── Undo/redo ciblé (D28) ────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            Button {
                objectName: "undoProposalButton"
                text: "Undo proposition"
                font.pixelSize: Theme.fontSizeSmall
                enabled: root._lastId !== ""
                onClicked: {
                    // Enregistre un write-set de test puis annule (D28).
                    EditorOpBus.registerProposalWriteSet(root._lastId, ["session/score"]);
                    const ok = EditorOpBus.undoProposal(root._lastId);
                    root._revertResult = "undo → " + ok;
                }
            }
            Button {
                objectName: "redoProposalButton"
                text: "Redo"
                font.pixelSize: Theme.fontSizeSmall
                enabled: root._lastId !== ""
                onClicked: {
                    const ok = EditorOpBus.redoProposal(root._lastId);
                    root._revertResult = "redo → " + ok;
                }
            }
            Text {
                objectName: "revertResultLabel"
                text: root._revertResult
                color: root.host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.family: "Consolas"
                Layout.fillWidth: true
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: root.host.cardBorder }

        // ── Compteurs lifecycle + transport ProposalSession ──────────────────
        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            Text { text: "lifecycle.proposalCount"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalLifecycle.proposalCount; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "lifecycle.queuedCount"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                objectName: "queuedCountLabel"
                text: "" + ProposalLifecycle.queuedCount
                color: ProposalLifecycle.queuedCount > 0 ? Theme.warning : root.host.textPrimary
                font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas"
            }

            Text { text: "session.active / isHost"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: ProposalSession.active + " / " + ProposalSession.isHost; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "session.busy / pending"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: ProposalSession.busy + " / " + ProposalSession.pendingCount; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
        }
    }
}
