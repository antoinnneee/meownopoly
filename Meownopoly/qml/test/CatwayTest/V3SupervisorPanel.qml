pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AiSupervisor 1.0
import theme
import ui_item

// Harness V3 — superviseur des process d'agents IA (M2/C5/C6).
//
// Panneau de test interactif : configuration d'adaptateur/programme/modèle/prompt
// par rôle, cycle de vie (start/stop/restart), challenge d'arbitre (C6, D24/D31),
// indicateur lobby 4-états, sortie récente scrollable et envoi d'entrée (C7).
Rectangle {
    id: root
    required property var host

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: content.implicitHeight + Theme.spacingXXL * 2

    // Rôle affiché par les onglets (0 = Proposante, 1 = Arbitre).
    readonly property int _role: roleTabs.currentIndex === 1
                                 ? AiProcessSupervisor.Arbiter
                                 : AiProcessSupervisor.Proposer
    // Sortie récente rafraîchie (recentOutput est Q_INVOKABLE, sans NOTIFY).
    property string _recentOutput: ""

    // Adapter-specific model values. The empty value delegates the choice to
    // the CLI. Claude aliases come from the installed CLI help; Codex values
    // mirror the locally advertised model cache.
    readonly property var _claudeModels: [
        { "label": "Par d\u00e9faut (Claude CLI)", "value": "" },
        { "label": "Sonnet", "value": "sonnet" },
        { "label": "Opus", "value": "opus" },
        { "label": "Fable", "value": "fable" }
    ]
    readonly property var _codexModels: [
        { "label": "Par d\u00e9faut (Codex CLI)", "value": "" },
        { "label": "GPT-5.6-Sol", "value": "gpt-5.6-sol" },
        { "label": "GPT-5.6-Terra", "value": "gpt-5.6-terra" },
        { "label": "GPT-5.6-Luna", "value": "gpt-5.6-luna" },
        { "label": "GPT-5.5", "value": "gpt-5.5" }
    ]

    function _stateName(s) {
        switch (s) {
        case AiProcessSupervisor.Stopped:    return "Stopped"
        case AiProcessSupervisor.Starting:   return "Starting"
        case AiProcessSupervisor.Ready:      return "Ready"
        case AiProcessSupervisor.Failed:     return "Failed"
        case AiProcessSupervisor.Restarting: return "Restarting"
        default:                             return "state=" + s
        }
    }
    function _stateColor(s) {
        switch (s) {
        case AiProcessSupervisor.Ready:      return Theme.success
        case AiProcessSupervisor.Starting:
        case AiProcessSupervisor.Restarting: return Theme.warning
        case AiProcessSupervisor.Failed:     return Theme.danger
        default:                             return root.host.textSecondary
        }
    }
    // Indicateur lobby 4-états (D31).
    function _lobbyName(s) {
        switch (s) {
        case AiProcessSupervisor.Absent:  return "Absent"
        case AiProcessSupervisor.Testing: return "Test en cours"
        case AiProcessSupervisor.Prete:   return "Prêt"
        case AiProcessSupervisor.Erreur:  return "Erreur"
        default:                          return "lobby=" + s
        }
    }
    function _lobbyColor(s) {
        switch (s) {
        case AiProcessSupervisor.Prete:   return Theme.success
        case AiProcessSupervisor.Testing: return Theme.warning
        case AiProcessSupervisor.Erreur:  return Theme.danger
        default:                          return root.host.textSecondary
        }
    }

    // Options de spawn construites depuis les champs de configuration.
    function _modelOptions(adapter) {
        return adapter === AiProcessSupervisor.Codex
                ? root._codexModels : root._claudeModels
    }
    function _defaultProgram(adapter) {
        return adapter === AiProcessSupervisor.Codex ? "codex" : "claude"
    }
    function _refreshOutput() {
        root._recentOutput = AiProcessSupervisor.recentOutput(root._role)
    }

    // — Inline styled controls (Theme) —
    component StyledButton: MeowButton {
        property color tint: root.host.accent
        baseColor: tint
        implicitHeight: Theme.px(28)
        padding: Theme.spacingM
        fontSize: Theme.fontSizeSmall
        hoverZoom: false
        glossy: false
    }
    component FieldLabel: Text {
        color: root.host.textSecondary
        font.pixelSize: Theme.fontSizeSmall
    }
    component StyledField: MeowTextField {
        fieldColor: Theme.surfaceAlt
        borderColor: root.host.cardBorder
    }

    component RoleTabButton: MeowTabButton {
        accentColor: Theme.accentAlt
    }

    component RolePane: ColumnLayout {
        id: rolePane
        required property int agentRole
        required property bool arbiter
        readonly property int currentState: arbiter
                                            ? AiProcessSupervisor.arbiterState
                                            : AiProcessSupervisor.proposerState
        spacing: Theme.spacingM

        function buildOpts() {
            const opts = {
                "adapter": adapterCombo.currentIndex,
                "program": programField.text.trim(),
                "prompt": promptField.text
            }
            const selectedModel = modelCombo.currentValue || ""
            if (selectedModel.length > 0)
                opts["model"] = selectedModel
            return opts
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingM

            Text {
                text: rolePane.arbiter ? "Agent arbitre" : "Agent proposant"
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }
            Rectangle {
                Layout.preferredHeight: Theme.px(22)
                Layout.preferredWidth: stateText.implicitWidth + Theme.spacingXL
                radius: Theme.radiusS
                color: Qt.rgba(root._stateColor(rolePane.currentState).r,
                               root._stateColor(rolePane.currentState).g,
                               root._stateColor(rolePane.currentState).b, 0.2)
                border.color: root._stateColor(rolePane.currentState)
                border.width: 1
                Text {
                    id: stateText
                    anchors.centerIn: parent
                    text: root._stateName(rolePane.currentState)
                    color: root._stateColor(rolePane.currentState)
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }
            Item { Layout.fillWidth: true }
        }

        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingM
            rowSpacing: Theme.spacingS
            Layout.fillWidth: true

            FieldLabel { text: "Adaptateur" }
            MeowComboBox {
                id: adapterCombo
                objectName: rolePane.arbiter ? "supArbiterAdapterCombo"
                                             : "supProposerAdapterCombo"
                Layout.fillWidth: true
                implicitHeight: Theme.px(30)
                model: ["claude (ClaudeCli)", "codex (Codex)"]
                currentIndex: 0
                onActivated: {
                    programField.text = root._defaultProgram(currentIndex)
                    modelCombo.currentIndex = 0
                }
            }

            FieldLabel { text: "Programme" }
            MeowTextField {
                id: programField
                objectName: rolePane.arbiter ? "supArbiterProgramField"
                                             : "supProposerProgramField"
                Layout.fillWidth: true
                text: "claude"
                placeholderText: "chemin/nom de l'exécutable CLI"
            }

            FieldLabel { text: "Mod\u00e8le" }
            MeowComboBox {
                id: modelCombo
                objectName: rolePane.arbiter ? "supArbiterModelCombo"
                                             : "supProposerModelCombo"
                Layout.fillWidth: true
                implicitHeight: Theme.px(30)
                model: root._modelOptions(adapterCombo.currentIndex)
                textRole: "label"
                valueRole: "value"
                currentIndex: 0
            }

            FieldLabel { text: "Prompt initial" }
            MeowTextField {
                id: promptField
                objectName: rolePane.arbiter ? "supArbiterPromptField"
                                             : "supProposerPromptField"
                Layout.fillWidth: true
                placeholderText: "instruction initiale (stdin)"
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            StyledButton {
                text: "Start"
                tint: Theme.success
                onClicked: AiProcessSupervisor.startAgent(rolePane.agentRole,
                                                          rolePane.buildOpts())
            }
            StyledButton {
                text: "Stop"
                onClicked: AiProcessSupervisor.stopAgent(rolePane.agentRole)
            }
            StyledButton {
                text: "Restart"
                onClicked: AiProcessSupervisor.restartAgent(rolePane.agentRole)
            }
            Item { Layout.fillWidth: true }
            StyledButton {
                visible: rolePane.arbiter
                text: "Tester l'arbitre"
                tint: root.host.accent
                onClicked: AiProcessSupervisor.testArbiter(rolePane.buildOpts())
            }
        }

        GridLayout {
            visible: rolePane.arbiter
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            FieldLabel { text: "Capacit\u00e9 valid\u00e9e" }
            Text {
                text: AiProcessSupervisor.arbiterReady ? "Oui" : "Non"
                color: AiProcessSupervisor.arbiterReady ? Theme.success
                                                        : root.host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                font.bold: true
            }
            FieldLabel { text: "Handshake" }
            Text {
                Layout.fillWidth: true
                text: AiProcessSupervisor.arbiterHandshakeReason || "Aucun test effectu\u00e9"
                color: root.host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
                wrapMode: Text.WrapAnywhere
            }
            FieldLabel { text: "Disponibilit\u00e9 lobby" }
            Rectangle {
                Layout.preferredHeight: Theme.px(22)
                Layout.preferredWidth: lobbyText.implicitWidth + Theme.spacingXL
                radius: Theme.radiusS
                color: Qt.rgba(root._lobbyColor(AiProcessSupervisor.arbiterLobbyState).r,
                               root._lobbyColor(AiProcessSupervisor.arbiterLobbyState).g,
                               root._lobbyColor(AiProcessSupervisor.arbiterLobbyState).b, 0.22)
                border.color: root._lobbyColor(AiProcessSupervisor.arbiterLobbyState)
                border.width: 1
                Text {
                    id: lobbyText
                    anchors.centerIn: parent
                    text: root._lobbyName(AiProcessSupervisor.arbiterLobbyState)
                    color: root._lobbyColor(AiProcessSupervisor.arbiterLobbyState)
                    font.pixelSize: Theme.fontSizeSmall
                    font.bold: true
                }
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: {
                rolePane.currentState
                return AiProcessSupervisor.lastError(rolePane.agentRole)
            }
            color: Theme.danger
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WrapAnywhere
        }
    }

    // Rafraîchit la sortie en direct.
    Connections {
        target: AiProcessSupervisor
        function onOutputReceived(r, chunk, isError) {
            if (r === root._role)
                root._refreshOutput()
        }
        function onStateChanged(r, s) {
            if (r === root._role)
                root._refreshOutput()
        }
        function onInvocationCompleted(r, code, output) {
            if (r === root._role)
                root._refreshOutput()
        }
    }
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: root._refreshOutput()
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM

        Text {
            text: "Superviseur agents IA"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "AiSupervisor 1.0 · AiProcessSupervisor — cycle de vie + handshake C6"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }

        // — Configuration —
        TabBar {
            id: roleTabs
            objectName: "supRoleTabs"
            Layout.fillWidth: true
            spacing: Theme.spacingS
            background: Rectangle {
                color: Theme.background
                radius: Theme.radiusS
            }
            onCurrentIndexChanged: root._refreshOutput()

            RoleTabButton {
                objectName: "supProposerTab"
                text: "Proposante"
                width: (roleTabs.width - roleTabs.spacing) / 2
            }
            RoleTabButton {
                objectName: "supArbiterTab"
                text: "Arbitre"
                width: (roleTabs.width - roleTabs.spacing) / 2
            }
        }

        StackLayout {
            id: roleStack
            Layout.fillWidth: true
            currentIndex: roleTabs.currentIndex

            RolePane {
                id: proposerPane
                agentRole: AiProcessSupervisor.Proposer
                arbiter: false
            }
            RolePane {
                id: arbiterPane
                agentRole: AiProcessSupervisor.Arbiter
                arbiter: true
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: root.host.cardBorder
        }

        FieldLabel { text: "Sortie récente (recentOutput)" }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(120)
            radius: Theme.radiusS
            color: Theme.background
            border.color: root.host.cardBorder
            border.width: 1
            ScrollView {
                anchors.fill: parent
                anchors.margins: Theme.spacingXS
                clip: true
                MeowTextArea {
                    id: outputArea
                    objectName: "supRecentOutput"
                    readOnly: true
                    text: root._recentOutput
                    color: root.host.textSecondary
                    font.pixelSize: Theme.fontSizeCaption
                    font.family: "Consolas"
                    wrapMode: TextArea.WrapAnywhere
                }
            }
        }

        // — Envoi d'entrée (C7) —
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingS
            StyledField {
                id: inputField
                objectName: "supInputField"
                Layout.fillWidth: true
                placeholderText: "texte à pousser sur stdin (un tour de tchat)…"
                onAccepted: sendBtn.clicked()
            }
            StyledButton {
                id: sendBtn
                objectName: "supSendBtn"
                text: "Envoyer"
                onClicked: {
                    if (inputField.text.length > 0) {
                        AiProcessSupervisor.sendInput(root._role, inputField.text)
                        inputField.text = ""
                        root._refreshOutput()
                    }
                }
            }
        }
    }
}
