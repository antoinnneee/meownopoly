import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ProposalSession 1.0
import MeowProposal 1.0
import theme

// PLACEHOLDER (étape 1 du harness V3) — pipeline de proposition : transport
// (ProposalSession, T3-2) + cycle de vie hôte P0 (ProposalLifecycle, S-1).
// Smoke test : lecture live de la garde de flux unique et des compteurs de
// file. Sera étoffé (start host/client, submit, verdict) par un agent suivant.
Rectangle {
    id: root
    required property var host

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: content.implicitHeight + Theme.spacingXXL * 2

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM

        Text {
            text: "Pipeline proposition"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "ProposalSession 1.0 + MeowProposal 1.0 · ProposalLifecycle  —  PLACEHOLDER"
            color: host.textSecondary
            font.pixelSize: Theme.fontSizeCaption
            font.italic: true
            Layout.fillWidth: true
        }

        GridLayout {
            columns: 2
            columnSpacing: Theme.spacingXL
            rowSpacing: Theme.spacingXS
            Layout.fillWidth: true

            Text { text: "session.active"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalSession.active; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "session.isHost"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalSession.isHost; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "session.busy"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalSession.busy; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "session.pendingCount"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalSession.pendingCount; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "lifecycle.proposalCount"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalLifecycle.proposalCount; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "lifecycle.queuedCount"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalLifecycle.queuedCount; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
        }
    }
}
