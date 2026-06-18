import QtQuick 2.15
import QtQuick.Controls

import UiStyle
import Catway 1.0
import EditorSession 1.0
import theme

Item {
    id: root

    // Placement dans la Column `leftBadgeStack` d'Editor.qml.
    width: Math.max(collabBadge.width, netStatsPanel.width)
    height: collabBadge.height + (netStatsPanel.visible ? 6 + netStatsPanel.height : 0)

    visible: EditorSession.active

    Rectangle {
        id: collabBadge
        anchors.top: parent.top
        anchors.left: parent.left
        width: badgeRow.implicitWidth + 20
        height: badgeRow.implicitHeight + 10
        radius: Theme.radiusM
        color: EditorSession.isHost ? "#1e4d3a" : "#1e3a5f"
        border.color: EditorSession.isHost ? Theme.success : Theme.accent
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: Theme.spacingM
            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: EditorSession.isHost ? Theme.success : Theme.accent
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (EditorSession.isHost ? "Collab · Hôte" : "Collab · Client")
                      + (EditorSession.sessionId ? "  (" + EditorSession.sessionId + ")" : "")
                color: Theme.textPrimary
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: netStatsPanel.open = !netStatsPanel.open
            acceptedButtons: Qt.LeftButton
        }
    }

    // panneau de stats de transmission (reliable.io par pair).
    // Toggle via clic sur le badge collab.
    Rectangle {
        id: netStatsPanel
        property bool open: false
        visible: EditorSession.active && open
        anchors.top: collabBadge.bottom
        anchors.left: parent.left
        anchors.topMargin: Theme.spacingS
        // Taille dérivée du contenu (dépendance UNIDIRECTIONNELLE contenu →
        // panneau). statsCol n'utilise volontairement PAS anchors.fill : un
        // Column rempli par un parent lui-même dimensionné sur l'implicitSize
        // du Column crée une boucle de polish — elle ne convergeait que parce
        // que les tailles tombaient juste à uiScale=1 ; dès que uiScale<1
        // introduit un arrondi via Theme.px(), les constantes en dur ne
        // correspondaient plus aux marges et la valeur oscillait à l'infini.
        width: Math.max(320, statsCol.implicitWidth + 2 * Theme.spacingL)
        height: statsCol.implicitHeight + 2 * Theme.spacingL
        radius: Theme.radiusL
        color: Theme.background
        border.color: Theme.border
        border.width: 1
        opacity: 0.95

        property var snapshots: ({})
        property int tick: 0

        Timer {
            interval: 500
            repeat: true
            running: netStatsPanel.visible
            onTriggered: {
                const snap = {}
                const n = Catway.playersCount()
                for (let i = 0; i < n; ++i) {
                    const p = Catway.playerAt(i)
                    if (p && p.p2pConnected && p.playerId) {
                        snap[p.playerId] = p.stats()
                    }
                }
                netStatsPanel.snapshots = snap
                netStatsPanel.tick += 1
            }
        }

        function _fmt(n, digits) {
            if (n === undefined || n === null) return "—"
            return Number(n).toFixed(digits === undefined ? 1 : digits)
        }

        function _playerIds() {
            const k = []
            for (const id in netStatsPanel.snapshots) k.push(id)
            k.sort()
            return k
        }

        Column {
            id: statsCol
            // Position/largeur explicites (pas anchors.fill) : la hauteur reste
            // auto (= implicitHeight, pilotée par le contenu) pour casser la
            // boucle de polish. La largeur suit le panneau pour que séparateur
            // et lignes occupent toute la largeur interne (y compris au plancher
            // de 320 px).
            x: Theme.spacingL
            y: Theme.spacingL
            width: netStatsPanel.width - 2 * Theme.spacingL
            spacing: Theme.spacingM

        //     Row {
        //         spacing: Theme.spacingS
        //         Text {
        //             text: "📊 Réseau (reliable.io)"
        //             color: Theme.textPrimary
        //             font.pixelSize: Theme.fontSizeBody
        //             font.bold: true
        //         }
        //         Text {
        //             text: "pairs: " + Object.keys(netStatsPanel.snapshots).length
        //                   + "  (tick " + netStatsPanel.tick + ")"
        //             color: Theme.textHint
        //             font.pixelSize: Theme.fontSizeSmall
        //         }
        //     }

        //     Rectangle { width: parent.width; height: 1; color: Theme.border }

        //     Repeater {
        //         model: (netStatsPanel.tick, netStatsPanel._playerIds())
        //         delegate: Column {
        //             width: statsCol.width
        //             spacing: Theme.spacingXXS
        //             readonly property var s: (netStatsPanel.tick,
        //                                       netStatsPanel.snapshots[modelData] || ({}))

        //             Text {
        //                 text: modelData.substring(0, 12)
        //                       + (EditorSession.hostPlayerId === modelData ? "  🛡️ hôte" : "")
        //                 color: Theme.textSecondary
        //                 font.pixelSize: Theme.fontSizeSmall
        //                 font.bold: true
        //                 font.family: "Consolas, Monaco, monospace"
        //             }
        //             Grid {
        //                 columns: 4
        //                 columnSpacing: Theme.spacingL
        //                 rowSpacing: Theme.spacingXXS
        //                 Text { text: "RTT";    color: Theme.textMuted; font.pixelSize: Theme.fontSizeCaption }
        //                 Text { text: netStatsPanel._fmt(s.rtt) + " ms";    color: Theme.textSoft; font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas, Monaco, monospace" }
        //                 Text { text: "loss";   color: Theme.textMuted; font.pixelSize: Theme.fontSizeCaption }
        //                 Text {
        //                     text: netStatsPanel._fmt(s.packetLoss || 0) + " %"
        //                     color: (s.packetLoss || 0) > 0.05 ? Theme.dangerSoft : Theme.textSoft
        //                     font.pixelSize: Theme.fontSizeCaption
        //                     font.family: "Consolas, Monaco, monospace"
        //                 }
        //                 Text { text: "sent";   color: Theme.textMuted; font.pixelSize: Theme.fontSizeCaption }
        //                 Text { text: netStatsPanel._fmt(s.sentBwKbps) + " kbps"; color: Theme.textSoft; font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas, Monaco, monospace" }
        //                 Text { text: "recv";   color: Theme.textMuted; font.pixelSize: Theme.fontSizeCaption }
        //                 Text { text: netStatsPanel._fmt(s.recvBwKbps) + " kbps"; color: Theme.textSoft; font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas, Monaco, monospace" }
        //                 Text { text: "acked";  color: Theme.textMuted; font.pixelSize: Theme.fontSizeCaption }
        //                 Text { text: netStatsPanel._fmt(s.ackedBwKbps) + " kbps"; color: Theme.textSoft; font.pixelSize: Theme.fontSizeCaption; font.family: "Consolas, Monaco, monospace" }
        //                 Text { text: "pkts";   color: Theme.textMuted; font.pixelSize: Theme.fontSizeCaption }
        //                 Text {
        //                     text: (s.packetsSent || 0) + "↑ / " + (s.packetsAcked || 0) + "✓"
        //                     color: Theme.textSoft
        //                     font.pixelSize: Theme.fontSizeCaption
        //                     font.family: "Consolas, Monaco, monospace"
        //                 }
        //                 Text { text: "frag";   color: Theme.textMuted; font.pixelSize: Theme.fontSizeCaption }
        //                 Text {
        //                     text: (s.fragmentsSent || 0) + "↑ / " + (s.fragmentsReceived || 0) + "↓"
        //                     color: Theme.textSoft
        //                     font.pixelSize: Theme.fontSizeCaption
        //                     font.family: "Consolas, Monaco, monospace"
        //                 }
        //             }
        //         }
        //     }

        //     Text {
        //         visible: Object.keys(netStatsPanel.snapshots).length === 0
        //         text: "Aucun pair P2P connecté."
        //         color: Theme.textMuted
        //         font.pixelSize: Theme.fontSizeCaption
        //         font.italic: true
        //     }
        }
    }
}
