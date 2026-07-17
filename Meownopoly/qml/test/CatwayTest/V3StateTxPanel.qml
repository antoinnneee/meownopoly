import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowMemory 1.0
import theme

// PLACEHOLDER (étape 1 du harness V3) — transport d'état runtime (StateBus,
// M6-B/D35) + espace mémoire session/joueurs (MemoryStore, S-4).
// Smoke test : lecture live des compteurs de deltas/snapshots du bus d'état et
// des portées mémoire connues. Sera étoffé (écritures, quotas, resync) par un
// agent suivant.
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
            text: "État runtime + mémoire"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "MeowMemory 1.0 · StateBus + MemoryStore  —  PLACEHOLDER"
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

            Text { text: "stateBus.active"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.active; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "stateBus.isHost"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.isHost; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "stateBus.deltasSent"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.deltasSent; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "stateBus.deltasReceived"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + StateBus.deltasReceived; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "memory.playerIds.length"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + MemoryStore.playerIds.length; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
        }
    }
}
