import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowProposal 1.0
import theme

// PLACEHOLDER (étape 1 du harness V3) — passerelle de proposition (S-1/T3-5).
// Smoke test : lecture du timeout côté tool (ProposalGateway) et de l'état des
// coutures d'intégration hôte (ProposalCollabBridge). Sera étoffé (soumission
// d'enveloppe, verdict, undo ciblé) par un agent suivant.
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
            text: "Passerelle proposition"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "MeowProposal 1.0 · ProposalGateway + ProposalCollabBridge  —  PLACEHOLDER"
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

            Text { text: "gateway.timeoutMs"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalGateway.timeoutMs; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "bridge.attached"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalCollabBridge.attached; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "bridge.deferHostApply"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + ProposalCollabBridge.deferHostApply; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
        }
    }
}
