import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import AiSupervisor 1.0
import theme

// PLACEHOLDER (étape 1 du harness V3) — superviseur des process d'agents IA
// (M2/C5/C6). Smoke test : lecture live des états proposante/arbitre et de
// l'indicateur lobby 4-états du handshake. Sera étoffé (spawn, handshake,
// output live) par un agent suivant.
Rectangle {
    id: root
    required property var host

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: content.implicitHeight + Theme.spacingXXL * 2

    // Nom lisible d'un State (Stopped/Starting/Ready/Failed/Restarting).
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

    ColumnLayout {
        id: content
        anchors.fill: parent
        anchors.margins: Theme.spacingXXL
        spacing: Theme.spacingM

        Text {
            text: "Superviseur agents IA"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
            Layout.fillWidth: true
        }
        Text {
            text: "AiSupervisor 1.0 · AiProcessSupervisor  —  PLACEHOLDER"
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

            Text { text: "proposerState"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: root._stateName(AiProcessSupervisor.proposerState); color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "arbiterState"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: root._stateName(AiProcessSupervisor.arbiterState); color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "arbiterLobbyState"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + AiProcessSupervisor.arbiterLobbyState; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "arbiterReady"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: "" + AiProcessSupervisor.arbiterReady; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }

            Text { text: "protocolVersion"; color: host.textSecondary; font.pixelSize: Theme.fontSizeSmall }
            Text { text: AiProcessSupervisor.protocolVersion; color: host.textPrimary; font.pixelSize: Theme.fontSizeSmall; font.family: "Consolas" }
        }
    }
}
