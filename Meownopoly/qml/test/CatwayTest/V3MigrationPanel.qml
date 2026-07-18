import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import EditorSession 1.0
import ProposalSession 1.0
import MeowMemory 1.0
import theme

// T4-3 — observabilité de la migration d'hôte et du checkpoint D37.
Rectangle {
    id: root
    required property var host
    property string _status: ""

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: contentColumn.implicitHeight + Theme.spacingXXL * 2

    function _checkpointText() {
        const checkpoint = EditorSession.migrationCheckpoint
        return Object.keys(checkpoint).length > 0
             ? JSON.stringify(checkpoint, null, 2)
             : "Aucun checkpoint reçu. Démarrez deux instances et provoquez un handover hôte."
    }

    ColumnLayout {
        id: contentColumn
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM
        Text {
            text: "Migration d'hôte V3"
            color: root.host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "T4-3 · checkpoint D37 · suspension puis reprise des propositions"
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }
        GridLayout {
            columns: 4
            columnSpacing: Theme.spacingL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true
            Text { text: "éditeur actif"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: EditorSession.active; color: EditorSession.active ? Theme.success : root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "rôle"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: EditorSession.isHost ? "hôte" : "client"; color: root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "migration"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: EditorSession.migrationInProgress; color: EditorSession.migrationInProgress ? Theme.warning : root.host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
            Text { text: "propositions"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: EditorSession.proposalsSuspended ? "suspendues" : "actives"; color: EditorSession.proposalsSuspended ? Theme.warning : Theme.success; font.pixelSize: Theme.fontSizeSmall }
        }
        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true
            Text { text: "session / hôte"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: (EditorSession.sessionId || "—") + " / " + (EditorSession.hostPlayerId || "—")
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeCaption
                font.family: "Consolas"
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }
            Text { text: "roster"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: EditorSession.knownRoster.length > 0 ? EditorSession.knownRoster.join(", ") : "—"
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeCaption
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text { text: "ProposalSession"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: (ProposalSession.active ? "active" : "arrêtée")
                      + " · " + (ProposalSession.isHost ? "hôte" : "client")
                      + " · pending=" + ProposalSession.pendingCount
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeCaption
            }
            Text { text: "StateBus"; color: root.host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text {
                text: (StateBus.active ? "active" : "arrêté")
                      + " · " + (StateBus.isHost ? "hôte" : "client")
                color: root.host.textPrimary
                font.pixelSize: Theme.fontSizeCaption
            }
        }
        TextArea {
            objectName: "migrationCheckpointArea"
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.px(175)
            readOnly: true
            text: root._checkpointText()
            wrapMode: TextEdit.Wrap
            font.family: "Consolas"
            font.pixelSize: Theme.fontSizeCaption
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
            spacing: Theme.spacingS
            Button {
                objectName: "migrationApplyCheckpointButton"
                text: "Appliquer checkpoint"
                enabled: EditorSession.migrationInProgress
                font.pixelSize: Theme.fontSizeSmall
                onClicked: {
                    const ok = EditorSession.applyMigrationCheckpoint()
                    root._status = ok ? "Checkpoint appliqué" : "Checkpoint bloquant incomplet"
                }
            }
            Button {
                objectName: "migrationResumeButton"
                text: "Reprendre propositions"
                enabled: EditorSession.proposalsSuspended
                font.pixelSize: Theme.fontSizeSmall
                onClicked: {
                    EditorSession.resumeProposals()
                    root._status = "Reprise demandée"
                }
            }
            Button {
                objectName: "migrationClearButton"
                text: "Effacer état"
                enabled: EditorSession.migrationInProgress
                         || EditorSession.proposalsSuspended
                font.pixelSize: Theme.fontSizeSmall
                onClicked: {
                    EditorSession.clearMigrationState()
                    root._status = "État de migration effacé"
                }
            }
        }
        Text {
            text: root._status || "Le handover réel se déclenche depuis une session de l'onglet Editor Network."
            color: root.host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }
    }
}
