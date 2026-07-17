import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import MeowEvents 1.0
import theme

// PLACEHOLDER (étape 1 du harness V3) — journal d'événements métier (M5, D4).
// Smoke test : lecture live des compteurs du singleton GameplayEventBus.
// Sera étoffé (ingestion, replay, audit) par un agent suivant.
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
            text: "Bus d'événements"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "MeowEvents 1.0 · GameplayEventBus  —  PLACEHOLDER"
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

            Text { text: "eventCount"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + GameplayEventBus.eventCount; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "logicalClock"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + GameplayEventBus.logicalClock; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "auditCount"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + GameplayEventBus.auditCount; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "rejectedCount"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + GameplayEventBus.rejectedCount; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
        }
    }
}
