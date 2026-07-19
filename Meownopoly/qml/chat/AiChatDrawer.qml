import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Meownopoly.Account 1.0
import AiSupervisor 1.0
import "."
import theme

/**
 * AiChatDrawer — tchat ingame IA (C7, doc/v3/14_ADAPTATEUR_AGENTS.md §2.4).
 *
 * UI de dialogue joueur↔IA depuis laquelle chaque invocation part et dans
 * laquelle reviennent réponses, verdicts (`reasons[audience=player]`, doc 13 §4)
 * et progression des propositions.
 *
 * **Distinct du chat multijoueur** (`ChatClient`/chatServer, doc 14 §3) : ce
 * drawer ne parle pas au serveur de chat et ne possède pas de `ChatClient`. Il
 * dialogue avec le superviseur d'agents (`AiProcessSupervisor`, C5) : une
 * invocation = un tour de tchat (modèle d'événements doc 02 §4). Il **réutilise
 * les composants visuels** de `qml/chat/` (bulles `ChatMessageDelegate`, barre
 * de statut `ChatStatusBar`) — réutilisation de composants UI seulement.
 *
 * Le drawer ne configure jamais d'arguments CLI en dur (doc 14 §2.2) : les
 * options d'invocation (program/token éphémère D20/gatewayUrl/skillPath) sont
 * fournies par l'intégrateur via `invocationOpts` (comme `AiHostLobby`).
 */
Drawer {
    id: aiDrawer
    width: 360
    height: parent ? parent.height : 0
    edge: Qt.RightEdge

    // — Contrat d'intégration —
    // Rôle d'agent adressé par le tchat. Par défaut le « proposer » : c'est
    // « son IA » que le joueur dirige (doc 00 §2). Les verdicts audience:player
    // qui reviennent proviennent de l'arbitre mais transitent par ce même fil.
    property int aiRole: AiProcessSupervisor.Proposer
    // Options d'invocation injectées au spawn (secrets par fichier/env, jamais
    // en clair dans l'UI). Fournies par l'hôte du mode IA (budget D10, token D20,
    // endpoint MCP loopback D21, pré-prompt skill D17…).
    property var invocationOpts: ({})

    // Même stockage que le menu du lobby IA : le modèle choisi avant la
    // partie devient le défaut effectif du tchat, sauf override explicite de
    // l'intégrateur dans invocationOpts.
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

    // Identité locale (utilisée par ChatMessageDelegate pour distinguer nos
    // bulles de celles de l'IA).
    property string playerId: "player"
    property string playerNickname: AccountManager.nickname

    // — État interne —
    // Une invocation à la fois (file implicite côté hôte, doc 13). Vrai pendant
    // qu'un tour est en vol → input désactivé + indicateur de progression.
    property bool _invocationPending: false
    // Bandeau d'information « captures d'écran actives » (D22) + prérequis
    // compte/CLI (doc 00 §8), affiché une fois au lancement du mode IA.
    property bool _showCaptureNotice: true
    // Modèle de conversation : tableau JS (pas ListModel) pour que
    // ChatMessageDelegate reçoive un `modelData` objet (mêmes champs que les
    // messages du chat multijoueur : sender/senderNickname/text/timestamp…).
    property var _messages: []

    signal focusReleased()

    // — API pour l'intégrateur (pipeline de proposition, Phase 2) —
    // Affiche un verdict d'arbitre côté joueur (reasons[audience=player], doc 13 §4).
    function pushVerdict(accepted, playerReason) {
        appendEntry("ai", accepted ? "⚖️ Arbitre — accepté" : "⚖️ Arbitre — refusé",
                    (playerReason && playerReason.length > 0)
                        ? playerReason
                        : (accepted ? "Proposition acceptée." : "Proposition refusée."),
                    "verdict")
    }
    // Affiche une note de progression d'une proposition (benching/applying…).
    function pushProgress(text) {
        appendEntry("ai", "⏳ Progression", text, "progress")
    }
    // Message système (erreurs actionnables, prérequis).
    function pushSystem(text) {
        appendEntry("ai", "🐾 Système", text, "system")
    }

    // — Helpers internes —
    function _roleLabel(role) {
        return role === AiProcessSupervisor.Arbiter ? "Arbitre" : "Assistant IA"
    }

    function _configuredInvocationOpts() {
        const arbiter = aiDrawer.aiRole === AiProcessSupervisor.Arbiter
        const adapter = arbiter ? aiModelSettings.arbiterAdapter
                                : aiModelSettings.proposerAdapter
        const program = arbiter ? aiModelSettings.arbiterProgram
                                : aiModelSettings.proposerProgram
        const model = arbiter ? aiModelSettings.arbiterModel
                              : aiModelSettings.proposerModel
        const opts = {
            "adapter": adapter,
            "program": program.length > 0
                     ? program
                     : (adapter === AiProcessSupervisor.Codex ? "codex" : "claude")
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
        return Object.assign(opts, aiDrawer.invocationOpts)
    }

    function appendEntry(sender, nickname, text, kind) {
        aiDrawer._messages = aiDrawer._messages.concat([{
            sender: sender,
            senderNickname: nickname,
            text: text,
            timestamp: Date.now(),
            kind: kind || "text",
            isImage: false,
            isTextFile: false,
            ephemeral: false
        }])
    }

    function formatTimestamp(ts) {
        if (!ts) return "--:--"
        let date = new Date(ts)
        if (isNaN(date.getTime())) return "" + ts
        const now = new Date()
        const isToday = date.getDate() === now.getDate() &&
            date.getMonth() === now.getMonth() &&
            date.getFullYear() === now.getFullYear()
        const hh = date.getHours().toString().padStart(2, '0')
        const mm = date.getMinutes().toString().padStart(2, '0')
        if (isToday) return hh + ":" + mm
        const dd = date.getDate().toString().padStart(2, '0')
        const mo = (date.getMonth() + 1).toString().padStart(2, '0')
        return dd + "/" + mo + " " + hh + ":" + mm
    }

    // Cherche un marqueur machine `MEOW_VERDICT:{json}` dans la sortie d'un tour
    // (l'agent peut émettre le verdict d'arbitre sur une ligne dédiée). Retourne
    // l'objet parsé {accepted, reasons:{player}} ou null.
    function _extractVerdict(output) {
        if (!output) return null
        const lines = output.split(/\r?\n/)
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            const idx = line.indexOf("MEOW_VERDICT:")
            if (idx >= 0) {
                try {
                    return JSON.parse(line.substring(idx + "MEOW_VERDICT:".length))
                } catch (e) {
                    return null
                }
            }
        }
        return null
    }

    // Envoie un tour de tchat : une invocation de l'agent. Modèle « une
    // invocation = un tour » (doc 02 §4) : chaque tour est une invocation
    // one-shot de l'agent avec le prompt du joueur.
    function submitTurn(rawText) {
        const text = ("" + rawText).trim()
        if (text.length === 0 || aiDrawer._invocationPending) return
        appendEntry(aiDrawer.playerId, aiDrawer.playerNickname, text, "text")
        aiDrawer._invocationPending = true

        // Option prioritaire : agent persistant déjà lancé → pousser le tour sur
        // son stdin. Sinon, invocation one-shot avec le prompt.
        if (AiProcessSupervisor.isRunning(aiDrawer.aiRole)) {
            AiProcessSupervisor.sendInput(aiDrawer.aiRole, text)
            return
        }
        const opts = Object.assign(aiDrawer._configuredInvocationOpts(),
                                   { oneShot: true, prompt: text })
        const ok = AiProcessSupervisor.startAgent(aiDrawer.aiRole, opts)
        if (!ok) {
            aiDrawer._invocationPending = false
            pushSystem("Impossible de démarrer l'IA. Vérifiez les prérequis (compte fournisseur + CLI installé, doc §8) et la configuration du mode IA.")
        }
    }

    background: Rectangle {
        color: Theme.background
        opacity: 0.98
        border.color: Theme.border
        border.width: 1
    }

    // — Réactions au superviseur d'agents —
    Connections {
        target: AiProcessSupervisor

        // Fin d'un tour one-shot : rendre la réponse (ou le verdict).
        function onInvocationCompleted(role, exitCode, output) {
            if (role !== aiDrawer.aiRole) return
            aiDrawer._invocationPending = false
            const verdict = aiDrawer._extractVerdict(output)
            if (verdict) {
                const playerReason = (verdict.reasons && verdict.reasons.player)
                    ? verdict.reasons.player : ""
                aiDrawer.pushVerdict(!!verdict.accepted, playerReason)
                return
            }
            const trimmed = ("" + (output || "")).trim()
            if (trimmed.length === 0) {
                aiDrawer.pushSystem(exitCode === 0
                    ? "L'IA n'a rien répondu pour ce tour."
                    : "L'IA a terminé en erreur (code " + exitCode + ").")
                return
            }
            aiDrawer.appendEntry("ai", aiDrawer._roleLabel(aiDrawer.aiRole), trimmed, "text")
        }

        // Échec d'agent pendant un tour → message actionnable.
        function onAgentFailed(role, reason) {
            if (role !== aiDrawer.aiRole || !aiDrawer._invocationPending) return
            aiDrawer._invocationPending = false
            aiDrawer.pushSystem("L'IA a échoué" + (reason && reason.length > 0 ? " : " + reason : "."))
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // — En-tête dédié IA (distinct de ChatHeader qui pilote des sessions) —
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            color: Theme.surfaceAlt
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.spacingXL
                anchors.rightMargin: Theme.spacingXL
                spacing: Theme.spacingM

                Text {
                    text: "🤖"
                    font.pixelSize: Theme.fontSizeHeading
                }
                Text {
                    text: "Assistant IA"
                    color: Theme.textSecondary
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    Layout.fillWidth: true
                }

                // Pastille d'état de l'agent (Prêt / en test / erreur).
                Rectangle {
                    Layout.preferredWidth: 10
                    Layout.preferredHeight: 10
                    radius: 5
                    readonly property int _st: AiProcessSupervisor.stateOf(aiDrawer.aiRole)
                    color: _st === AiProcessSupervisor.Ready ? Theme.success
                         : _st === AiProcessSupervisor.Failed ? Theme.danger
                         : _st === AiProcessSupervisor.Stopped ? Theme.textDisabled
                         : Theme.warning
                    SequentialAnimation on opacity {
                        running: {
                            const s = AiProcessSupervisor.stateOf(aiDrawer.aiRole)
                            return s === AiProcessSupervisor.Starting || s === AiProcessSupervisor.Restarting
                        }
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.4; duration: 700 }
                        NumberAnimation { to: 1.0; duration: 700 }
                    }
                }

                // Fermeture du drawer.
                Rectangle {
                    Layout.preferredWidth: 24
                    Layout.preferredHeight: 24
                    color: closeArea.containsMouse ? Theme.border : "transparent"
                    radius: Theme.radiusS
                    Text {
                        text: "✕"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeBody
                        anchors.centerIn: parent
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: aiDrawer.close()
                    }
                }
            }
        }

        // — Bandeau d'information « captures actives » (D22) + prérequis —
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: aiDrawer._showCaptureNotice ? noticeCol.implicitHeight + 2 * Theme.spacingM : 0
            visible: aiDrawer._showCaptureNotice
            color: "#2a2438"
            border.color: Theme.accent
            border.width: 1
            clip: true

            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durationNormal } }

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Text {
                    text: "ℹ️"
                    font.pixelSize: Theme.fontSizeBody
                    Layout.alignment: Qt.AlignTop
                }
                ColumnLayout {
                    id: noticeCol
                    Layout.fillWidth: true
                    spacing: Theme.spacingXXS
                    Text {
                        text: "Captures d'écran actives"
                        color: Theme.accent
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                    Text {
                        text: "L'IA peut recevoir des captures de la scène pour analyser vos demandes. Prérequis : compte fournisseur connecté et CLI installé."
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeTiny
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                    }
                }
                Rectangle {
                    Layout.preferredWidth: 20
                    Layout.preferredHeight: 20
                    Layout.alignment: Qt.AlignTop
                    color: noticeCloseArea.containsMouse ? Theme.border : "transparent"
                    radius: Theme.radiusXS
                    Text {
                        text: "✕"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.centerIn: parent
                    }
                    MouseArea {
                        id: noticeCloseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: aiDrawer._showCaptureNotice = false
                    }
                }
            }
        }

        // — Liste des tours (réutilise ChatMessageDelegate) —
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface
            border.color: Theme.border
            border.width: 1

            ListView {
                id: messageList
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                model: aiDrawer._messages
                clip: true
                spacing: Theme.spacingXS
                reuseItems: true
                cacheBuffer: 2000

                property bool stickToBottom: true

                function snapToBottom() { positionViewAtEnd() }

                onContentHeightChanged: if (stickToBottom) positionViewAtEnd()
                onMovementEnded: stickToBottom = atYEnd
                onCountChanged: if (stickToBottom) positionViewAtEnd()

                ScrollBar.vertical: ScrollBar {
                    active: true
                    policy: ScrollBar.AsNeeded
                }

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: messageList.width - 16
                    height: delegateImpl.height + 8
                    x: 8

                    readonly property bool isOwn: modelData && (modelData.sender === aiDrawer.playerId)

                    ChatMessageDelegate {
                        id: delegateImpl
                        drawer: aiDrawer
                        listView: messageList
                        modelData: parent.modelData
                        index: parent.index
                        chatClient: null
                        anchors.top: parent.top
                        anchors.topMargin: Theme.spacingXS
                        anchors.left: parent.isOwn ? undefined : parent.left
                        anchors.right: parent.isOwn ? parent.right : undefined
                    }
                }

                // État vide.
                Rectangle {
                    anchors.centerIn: parent
                    width: 220
                    height: 90
                    color: Theme.surfaceAlt
                    radius: Theme.radiusL
                    border.color: Theme.border
                    border.width: 1
                    visible: messageList.count === 0

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.spacingM
                        Text {
                            text: "🤖"
                            font.pixelSize: Theme.fontSizeDisplay
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Dialoguez avec votre IA"
                            color: Theme.textMuted
                            font.pixelSize: Theme.fontSizeSmall
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                        Text {
                            text: "Une demande = un tour."
                            color: Theme.textDisabled
                            font.pixelSize: Theme.fontSizeTiny
                            anchors.horizontalCenter: parent.horizontalCenter
                        }
                    }
                }
            }
        }

        // — Indicateur de progression (tour en vol) —
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: aiDrawer._invocationPending ? 30 : 0
            visible: aiDrawer._invocationPending
            color: Theme.surfaceAlt
            clip: true

            Behavior on Layout.preferredHeight { NumberAnimation { duration: Theme.durationFast } }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.spacingS
                BusyIndicator {
                    running: aiDrawer._invocationPending
                    Layout.preferredWidth: 18
                    Layout.preferredHeight: 18
                }
                Text {
                    text: "L'IA réfléchit…"
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }

        // — Barre de saisie (un tour à la fois) —
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 60
            color: Theme.surfaceAlt
            border.color: Theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingM

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.surface
                    radius: Theme.radiusM
                    border.color: inputField.activeFocus ? Theme.accent : Theme.border
                    border.width: 1
                    opacity: aiDrawer._invocationPending ? 0.5 : 1.0

                    Behavior on border.color { ColorAnimation { duration: Theme.durationNormal } }

                    TextField {
                        id: inputField
                        anchors.fill: parent
                        anchors.margins: Theme.spacingXS
                        enabled: !aiDrawer._invocationPending
                        placeholderText: aiDrawer._invocationPending
                            ? "Tour en cours…"
                            : "Demandez à votre IA…"
                        placeholderTextColor: Theme.textDisabled
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeBody
                        background: Rectangle { color: "transparent" }
                        onAccepted: {
                            aiDrawer.submitTurn(inputField.text)
                            inputField.text = ""
                            inputField.focus = false
                            aiDrawer.focusReleased()
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 60
                    Layout.preferredHeight: 36
                    readonly property bool _canSend: inputField.text.trim() !== "" && !aiDrawer._invocationPending
                    color: sendBtnArea.pressed
                        ? Theme.pressed(Theme.success)
                        : (sendBtnArea.containsMouse ? Theme.hover(Theme.success) : Theme.success)
                    radius: Theme.radiusM
                    border.color: Theme.success
                    border.width: 1
                    opacity: _canSend ? 1.0 : 0.5

                    Behavior on color { ColorAnimation { duration: Theme.durationFast } }
                    Behavior on opacity { NumberAnimation { duration: Theme.durationNormal } }

                    Text {
                        text: "Envoyer"
                        color: Theme.textPrimary
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: sendBtnArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            if (!parent._canSend) return
                            aiDrawer.submitTurn(inputField.text)
                            inputField.text = ""
                            inputField.focus = false
                            aiDrawer.focusReleased()
                        }
                    }
                }
            }
        }

        // — Barre de statut (réutilise ChatStatusBar) —
        ChatStatusBar {
            connected: AiProcessSupervisor.stateOf(aiDrawer.aiRole) === AiProcessSupervisor.Ready
            messageCount: messageList.count
            playerNickname: aiDrawer.playerNickname
            participantCount: 0
        }
    }

    enter: Transition {
        NumberAnimation { property: "position"; from: 0; to: 1; duration: 250; easing.type: Easing.OutCubic }
    }
    exit: Transition {
        NumberAnimation { property: "position"; from: 1; to: 0; duration: 200; easing.type: Easing.InCubic }
    }
}
