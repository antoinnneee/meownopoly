import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import theme
import AiSupervisor
import ui_item

/*
 * AiHostLobby.qml — Lobby « Héberger une partie IA » (C6, D24/D31).
 *
 * Panneau réutilisable et autonome qui matérialise le prérequis arbitre avant
 * d'ouvrir le mode IA :
 *   - indicateur d'état à 4 valeurs (Absent → Test en cours → Prêt → Erreur),
 *     lié à AiProcessSupervisor.arbiterLobbyState (projection D31 qui intègre le
 *     résultat du handshake/challenge, pas seulement l'état du process) ;
 *   - motif actionnable affiché à côté en cas d'Erreur (pas de dialogue
 *     bloquant, D31) ;
 *   - bouton « Tester l'arbitre » (re-test manuel) + test AUTOMATIQUE à
 *     l'ouverture (Component.onCompleted) ;
 *   - bouton « Héberger une partie IA » GRISÉ tant que l'état ≠ Prêt.
 *
 * Ce composant ne lance pas la partie lui-même : il émet `hostRequested(config)` que
 * le flux d'intégration (C7 / menu) branche. Les options du challenge (token de
 * rôle éphémère D20, programme CLI, URL passerelle, skill) sont fournies par le
 * contexte via `handshakeOpts` — jamais codées en dur ici (doc 14 §2.2).
 */
Item {
    id: root

    // Options passées au challenge d'arbitre (voir AiProcessSupervisor.startAgent).
    // Ex. { token, program, adapter, gatewayUrl, skillPath, model }. Le token
    // (D20) est un secret : il n'apparaît jamais dans l'UI ni les logs.
    property var handshakeOpts: ({})

    // Lance-t-on un test automatique dès l'affichage du lobby ? (D31)
    property bool autoTestOnOpen: true

    // Journal local borné du préflight. Les tokens sont masqués avant affichage.
    property string _diagnosticLog: ""
    property bool _diagnosticExpanded: false
    property bool _configExpanded: false

    readonly property var _claudeModels: [
        { "label": qsTr("Par défaut (Claude CLI)"), "value": "" },
        { "label": "Sonnet", "value": "sonnet" },
        { "label": "Opus", "value": "opus" },
        { "label": "Fable", "value": "fable" }
    ]
    readonly property var _codexModels: [
        { "label": qsTr("Par défaut (Codex CLI)"), "value": "" },
        { "label": "GPT-5.6-Sol", "value": "gpt-5.6-sol" },
        { "label": "GPT-5.6-Terra", "value": "gpt-5.6-terra" },
        { "label": "GPT-5.6-Luna", "value": "gpt-5.6-luna" },
        { "label": "GPT-5.5", "value": "gpt-5.5" }
    ]

    Settings {
        id: aiModelSettings
        category: "AI/ModelConfig"
        property int arbiterAdapter: AiProcessSupervisor.ClaudeCli
        property string arbiterProgram: "claude"
        property string arbiterModel: ""
        property int proposerAdapter: AiProcessSupervisor.ClaudeCli
        property string proposerProgram: "claude"
        property string proposerModel: ""
    }

    // Émis quand le joueur clique « Héberger une partie IA » (état Prêt requis).
    signal hostRequested(var aiConfig)

    implicitWidth: Theme.px(620)
    implicitHeight: content.implicitHeight + 2 * Theme.spacingXL

    // Résout l'état lobby courant de l'arbitre en (couleur, libellé).
    readonly property int _lobby: AiProcessSupervisor.arbiterLobbyState
    readonly property color _stateColor:
          _lobby === AiProcessSupervisor.Prete   ? Theme.success
        : _lobby === AiProcessSupervisor.Testing ? Theme.warning
        : _lobby === AiProcessSupervisor.Erreur  ? Theme.danger
        : Theme.textSecondary
    readonly property string _stateLabel:
          _lobby === AiProcessSupervisor.Prete   ? qsTr("Prêt")
        : _lobby === AiProcessSupervisor.Testing ? qsTr("Test en cours…")
        : _lobby === AiProcessSupervisor.Erreur  ? qsTr("Erreur")
        : qsTr("Absent")

    function _modelsFor(adapter) {
        return adapter === AiProcessSupervisor.Codex
                ? root._codexModels : root._claudeModels
    }

    function _defaultProgram(adapter) {
        return adapter === AiProcessSupervisor.Codex ? "codex" : "claude"
    }

    function _modelIndex(modelList, value) {
        for (let i = 0; i < modelList.length; ++i) {
            if (modelList[i].value === value)
                return i
        }
        return 0
    }

    function _configuredOptions(role) {
        const arbiter = role === AiProcessSupervisor.Arbiter
        const adapter = arbiter ? aiModelSettings.arbiterAdapter
                                : aiModelSettings.proposerAdapter
        const program = arbiter ? aiModelSettings.arbiterProgram
                                : aiModelSettings.proposerProgram
        const model = arbiter ? aiModelSettings.arbiterModel
                              : aiModelSettings.proposerModel
        const opts = {
            "adapter": adapter,
            "program": program.length > 0 ? program : root._defaultProgram(adapter)
        }
        if (model.length > 0)
            opts["model"] = model

        const port = AiProcessSupervisor.gatewayPort()
        const token = arbiter ? AiProcessSupervisor.gatewayArbiterToken()
                              : AiProcessSupervisor.gatewayProposerToken()
        if (port > 0)
            opts["gatewayUrl"] = "http://127.0.0.1:" + port + "/mcp"
        if (token.length > 0)
            opts["token"] = token

        // Les options fournies par l'intégrateur restent prioritaires.
        return Object.assign(opts, root.handshakeOpts)
    }

    function _sessionRoleConfig(role) {
        const arbiter = role === AiProcessSupervisor.Arbiter
        const adapter = arbiter ? aiModelSettings.arbiterAdapter
                                : aiModelSettings.proposerAdapter
        const program = arbiter ? aiModelSettings.arbiterProgram
                                : aiModelSettings.proposerProgram
        const model = arbiter ? aiModelSettings.arbiterModel
                              : aiModelSettings.proposerModel
        return {
            "adapter": adapter,
            "program": program.length > 0 ? program : root._defaultProgram(adapter),
            "model": model
        }
    }

    function sessionConfig() {
        return {
            "proposer": root._sessionRoleConfig(AiProcessSupervisor.Proposer),
            "arbiter": root._sessionRoleConfig(AiProcessSupervisor.Arbiter)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.surface
        radius: Theme.radiusL
        border.color: Theme.border
        border.width: 1

        ColumnLayout {
            id: content
            anchors.fill: parent
            anchors.margins: Theme.spacingXL
            spacing: Theme.spacingL

            Text {
                text: qsTr("Arbitre IA")
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
            }

            // — Indicateur 4 états (pastille + libellé) —
            RowLayout {
                spacing: Theme.spacingM
                Layout.fillWidth: true

                Rectangle {
                    width: Theme.fontSizeBody
                    height: width
                    radius: width / 2
                    color: root._stateColor
                    // Pulsation discrète pendant le test.
                    SequentialAnimation on opacity {
                        running: root._lobby === AiProcessSupervisor.Testing
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 600 }
                        NumberAnimation { to: 1.0; duration: 600 }
                    }
                }
                Text {
                    text: root._stateLabel
                    color: root._stateColor
                    font.pixelSize: Theme.fontSizeMedium
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                BusyIndicator {
                    running: root._lobby === AiProcessSupervisor.Testing
                    visible: running
                    implicitWidth: Theme.fontSizeHeading
                    implicitHeight: Theme.fontSizeHeading
                }
            }

            MeowButton {
                Layout.fillWidth: true
                variant: "secondary"
                glossy: false
                hoverZoom: false
                text: root._configExpanded
                      ? qsTr("Masquer la configuration des modèles")
                      : qsTr("Configurer les modèles utilisés")
                onClicked: root._configExpanded = !root._configExpanded
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: modelConfigContent.implicitHeight
                                        + 2 * Theme.spacingL
                visible: root._configExpanded
                color: Theme.surfaceAlt
                radius: Theme.radiusM
                border.color: Theme.border
                border.width: 1

                GridLayout {
                    id: modelConfigContent
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: Theme.spacingL
                    }
                    columns: 3
                    columnSpacing: Theme.spacingM
                    rowSpacing: Theme.spacingS

                    Text {
                        text: qsTr("Rôle")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeCaption
                        font.bold: true
                    }
                    Text {
                        text: qsTr("Fournisseur")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeCaption
                        font.bold: true
                    }
                    Text {
                        text: qsTr("Modèle")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeCaption
                        font.bold: true
                    }

                    Text {
                        text: qsTr("Arbitre")
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                    }
                    MeowComboBox {
                        id: arbiterAdapterCombo
                        objectName: "aiArbiterAdapterCombo"
                        Layout.preferredWidth: Theme.px(145)
                        model: ["Claude CLI", "Codex"]
                        currentIndex: aiModelSettings.arbiterAdapter
                        onActivated: function(index) {
                            aiModelSettings.arbiterAdapter = index
                            aiModelSettings.arbiterProgram = root._defaultProgram(index)
                            aiModelSettings.arbiterModel = ""
                        }
                    }
                    MeowComboBox {
                        id: arbiterModelCombo
                        objectName: "aiArbiterModelCombo"
                        Layout.fillWidth: true
                        model: root._modelsFor(aiModelSettings.arbiterAdapter)
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: root._modelIndex(model, aiModelSettings.arbiterModel)
                        onActivated: aiModelSettings.arbiterModel = currentValue
                    }

                    Text {
                        text: qsTr("Exécutable")
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    MeowTextField {
                        objectName: "aiArbiterProgramField"
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        text: aiModelSettings.arbiterProgram
                        placeholderText: root._defaultProgram(aiModelSettings.arbiterAdapter)
                        onEditingFinished: aiModelSettings.arbiterProgram = text.trim()
                    }

                    Rectangle {
                        Layout.columnSpan: 3
                        Layout.fillWidth: true
                        Layout.preferredHeight: Theme.px(1)
                        color: Theme.border
                    }

                    Text {
                        text: qsTr("Assistant")
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeBody
                        font.bold: true
                    }
                    MeowComboBox {
                        id: proposerAdapterCombo
                        objectName: "aiProposerAdapterCombo"
                        Layout.preferredWidth: Theme.px(145)
                        model: ["Claude CLI", "Codex"]
                        currentIndex: aiModelSettings.proposerAdapter
                        onActivated: function(index) {
                            aiModelSettings.proposerAdapter = index
                            aiModelSettings.proposerProgram = root._defaultProgram(index)
                            aiModelSettings.proposerModel = ""
                        }
                    }
                    MeowComboBox {
                        id: proposerModelCombo
                        objectName: "aiProposerModelCombo"
                        Layout.fillWidth: true
                        model: root._modelsFor(aiModelSettings.proposerAdapter)
                        textRole: "label"
                        valueRole: "value"
                        currentIndex: root._modelIndex(model, aiModelSettings.proposerModel)
                        onActivated: aiModelSettings.proposerModel = currentValue
                    }

                    Text {
                        text: qsTr("Exécutable")
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    MeowTextField {
                        objectName: "aiProposerProgramField"
                        Layout.columnSpan: 2
                        Layout.fillWidth: true
                        text: aiModelSettings.proposerProgram
                        placeholderText: root._defaultProgram(aiModelSettings.proposerAdapter)
                        onEditingFinished: aiModelSettings.proposerProgram = text.trim()
                    }

                    Text {
                        Layout.columnSpan: 3
                        Layout.fillWidth: true
                        text: qsTr("L’arbitre est utilisé pour le test ci-dessous. "
                                   + "L’assistant sera utilisé par le tchat IA en partie.")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeCaption
                        wrapMode: Text.WordWrap
                    }
                }
            }

            // — Motif actionnable en cas d'erreur (D31 : pas de modale) —
            Text {
                Layout.fillWidth: true
                visible: root._lobby === AiProcessSupervisor.Erreur
                         && text.length > 0
                text: AiProcessSupervisor.arbiterHandshakeReason
                color: Theme.danger
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
            }

            Text {
                Layout.fillWidth: true
                visible: root._lobby === AiProcessSupervisor.Absent
                text: qsTr("Aucun arbitre validé. Lancez un test pour vérifier "
                           + "qu'un arbitre fonctionnel est branché.")
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeSmall
            }

            // — Actions —
            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                MeowButton {
                    variant: "secondary"
                    glossy: false
                    hoverZoom: false
                    text: root._lobby === AiProcessSupervisor.Testing
                          ? qsTr("Test en cours…")
                          : qsTr("Tester l'arbitre")
                    enabled: root._lobby !== AiProcessSupervisor.Testing
                    onClicked: root.startTest()
                }

                Item { Layout.fillWidth: true }

                MeowButton {
                    variant: "success"
                    hoverZoom: false
                    text: qsTr("Héberger une partie IA")
                    // Grisé tant que l'arbitre n'est pas Prêt (D31).
                    enabled: AiProcessSupervisor.arbiterReady
                    onClicked: root.hostRequested(root.sessionConfig())
                }
            }

            // Motif du grisage, affiché à côté du bouton (pas de modale, D31).
            Text {
                Layout.fillWidth: true
                visible: !AiProcessSupervisor.arbiterReady
                text: root._lobby === AiProcessSupervisor.Testing
                      ? qsTr("Vérification de l'arbitre…")
                      : qsTr("« Héberger une partie IA » sera disponible une fois "
                             + "l'arbitre validé.")
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
                font.pixelSize: Theme.fontSizeCaption
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.spacingM

                MeowButton {
                    variant: "ghost"
                    glossy: false
                    hoverZoom: false
                    text: root._diagnosticExpanded
                          ? qsTr("Masquer les logs") : qsTr("Afficher les logs")
                    onClicked: root._diagnosticExpanded = !root._diagnosticExpanded
                }
                Item { Layout.fillWidth: true }
                MeowButton {
                    visible: root._diagnosticExpanded
                    variant: "ghost"
                    glossy: false
                    hoverZoom: false
                    text: qsTr("Effacer")
                    onClicked: root._diagnosticLog = ""
                }
            }

            MeowTextArea {
                id: diagnosticArea
                objectName: "aiHostDiagnosticLog"
                Layout.fillWidth: true
                Layout.preferredHeight: root._diagnosticExpanded ? Theme.px(180) : 0
                visible: root._diagnosticExpanded
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                text: root._diagnosticLog.length > 0
                      ? root._diagnosticLog : qsTr("Aucun événement enregistré.")
                color: Theme.textSecondary
                font.family: Theme.fontFamilyMonospace
                font.pixelSize: Theme.fontSizeCaption
            }
        }
    }

    function _sanitize(message) {
        let safe = String(message)
        const proposerToken = AiProcessSupervisor.gatewayProposerToken()
        const arbiterToken = AiProcessSupervisor.gatewayArbiterToken()
        if (proposerToken.length > 0)
            safe = safe.split(proposerToken).join("[TOKEN MASQUÉ]")
        if (arbiterToken.length > 0)
            safe = safe.split(arbiterToken).join("[TOKEN MASQUÉ]")
        return safe
    }

    function _appendDiagnostic(message) {
        const clean = root._sanitize(message).trim()
        if (clean.length === 0)
            return
        const now = new Date()
        const hh = now.getHours().toString().padStart(2, "0")
        const mm = now.getMinutes().toString().padStart(2, "0")
        const ss = now.getSeconds().toString().padStart(2, "0")
        const line = "[" + hh + ":" + mm + ":" + ss + "] " + clean
        const combined = root._diagnosticLog.length > 0
                       ? root._diagnosticLog + "\n" + line : line
        root._diagnosticLog = combined.length > 12000
                            ? combined.slice(combined.length - 12000) : combined
        diagnosticArea.cursorPosition = diagnosticArea.length
    }

    /// Lance (ou relance) le handshake/challenge de l'arbitre.
    function startTest() {
        root._diagnosticLog = ""
        const opts = root._configuredOptions(AiProcessSupervisor.Arbiter)
        root._appendDiagnostic(
            "Passerelle MCP : présente=" + AiProcessSupervisor.gatewayPresent()
            + ", écoute=" + AiProcessSupervisor.gatewayListening()
            + ", HTTP=" + AiProcessSupervisor.gatewayHttpAvailable()
            + ", port=" + AiProcessSupervisor.gatewayPort())
        root._appendDiagnostic(
            "Arbitre : programme=" + opts.program
            + ", adaptateur=" + (opts.adapter === AiProcessSupervisor.Codex
                                  ? "Codex" : "Claude")
            + ", modèle=" + (opts.model || "défaut")
            + ", token=" + (opts.token ? "présent" : "absent")
            + ", gatewayUrl=" + (opts.gatewayUrl ? "présente" : "absente"))
        AiProcessSupervisor.testArbiter(opts)
    }

    // Test automatique à l'ouverture du lobby (D31).
    Component.onCompleted: {
        if (autoTestOnOpen
                && AiProcessSupervisor.arbiterLobbyState !== AiProcessSupervisor.Testing)
            startTest()
    }

    // Journalise l'issue du challenge pour diagnostic (optionnel).
    Connections {
        target: AiProcessSupervisor
        function onLogMessage(message) {
            root._appendDiagnostic(message)
            console.log(message)
        }
        function onOutputReceived(role, chunk, isError) {
            if (role !== AiProcessSupervisor.Arbiter)
                return
            root._appendDiagnostic((isError ? "stderr | " : "stdout | ") + chunk)
            if (isError)
                console.warn("[AiHostLobby][stderr]", root._sanitize(chunk))
            else
                console.log("[AiHostLobby][stdout]", root._sanitize(chunk))
        }
        function onHandshakeStarted(role) {
            if (role === AiProcessSupervisor.Arbiter)
                root._appendDiagnostic("Challenge de l'arbitre démarré.")
        }
        function onHandshakeCompleted(role, ok, reason) {
            if (role !== AiProcessSupervisor.Arbiter)
                return
            root._appendDiagnostic(ok ? "Handshake validé."
                                      : "Handshake refusé : " + reason)
            if (!ok) {
                root._diagnosticExpanded = true
                console.warn("[AiHostLobby] handshake arbitre échoué :", reason)
            }
        }
    }
}
