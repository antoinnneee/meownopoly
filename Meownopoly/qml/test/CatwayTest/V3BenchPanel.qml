import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowSlice 1.0
import theme

// PLACEHOLDER (étape 1 du harness V3) — banc d'essai / instrumentation de la
// slice (A7/A8, doc 11-12). Smoke test : lecture live du rapport
// d'instrumentation (invocations, stall GUI, accès hors canal, verdict global).
// Sera étoffé (lancement de scénarios, critères R1, verdicts) par un agent
// suivant.
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
            text: "Banc d'essai / instrumentation"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "MeowSlice 1.0 · SliceInstrumentation  —  PLACEHOLDER"
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

            Text { text: "invocationCount"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + SliceInstrumentation.invocationCount; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "maxGuiStallMs"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + SliceInstrumentation.maxGuiStallMs; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "offChannelAccessCount"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + SliceInstrumentation.offChannelAccessCount; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "overallPass"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + SliceInstrumentation.overallPass; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
        }
    }
}
