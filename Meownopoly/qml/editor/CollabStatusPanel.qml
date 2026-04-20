import QtQuick 2.15
import QtQuick.Controls

import UiStyle
import Catway 1.0
import EditorSession 1.0

Item {
    id: root

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.topMargin: 12
    anchors.leftMargin: 12

    z: 10000
    width: Math.max(collabBadge.width, netStatsPanel.width)
    height: collabBadge.height + (netStatsPanel.visible ? 6 + netStatsPanel.height : 0)

    visible: EditorSession.active

    Rectangle {
        id: collabBadge
        anchors.top: parent.top
        anchors.left: parent.left
        width: badgeRow.implicitWidth + 20
        height: badgeRow.implicitHeight + 10
        radius: 6
        color: EditorSession.isHost ? "#1e4d3a" : "#1e3a5f"
        border.color: EditorSession.isHost ? "#22c55e" : "#3b82f6"
        border.width: 1

        Row {
            id: badgeRow
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 10
                height: 10
                radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: EditorSession.isHost ? "#22c55e" : "#3b82f6"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: (EditorSession.isHost ? "Collab · Hôte" : "Collab · Client")
                      + (EditorSession.sessionId ? "  (" + EditorSession.sessionId + ")" : "")
                color: "#f4f4f5"
                font.pixelSize: 12
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
    // Toggle via clic sur le badge collab. Poll @ 2 Hz.
    Rectangle {
        id: netStatsPanel
        property bool open: false
        visible: EditorSession.active && open
        anchors.top: collabBadge.bottom
        anchors.left: parent.left
        anchors.topMargin: 6
        width: Math.max(320, statsCol.implicitWidth + 20)
        height: statsCol.implicitHeight + 16
        radius: 8
        color: "#0f172a"
        border.color: "#334155"
        border.width: 1
        opacity: 0.95

        property var snapshots: ({})
        property int tick: 0

        Timer {
            interval: 250
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
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            Row {
                spacing: 6
                Text {
                    text: "📊 Réseau (reliable.io)"
                    color: "#f1f5f9"
                    font.pixelSize: 12
                    font.bold: true
                }
                Text {
                    text: "pairs: " + Object.keys(netStatsPanel.snapshots).length
                          + "  (tick " + netStatsPanel.tick + ")"
                    color: "#94a3b8"
                    font.pixelSize: 11
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#1e293b" }

            Repeater {
                model: (netStatsPanel.tick, netStatsPanel._playerIds())
                delegate: Column {
                    width: statsCol.width
                    spacing: 3
                    readonly property var s: (netStatsPanel.tick,
                                              netStatsPanel.snapshots[modelData] || ({}))

                    Text {
                        text: modelData.substring(0, 12)
                              + (EditorSession.hostPlayerId === modelData ? "  🛡️ hôte" : "")
                        color: "#cbd5e1"
                        font.pixelSize: 11
                        font.bold: true
                        font.family: "Consolas, Monaco, monospace"
                    }
                    Grid {
                        columns: 4
                        columnSpacing: 10
                        rowSpacing: 2
                        Text { text: "RTT";    color: "#64748b"; font.pixelSize: 10 }
                        Text { text: netStatsPanel._fmt(s.rtt) + " ms";    color: "#e2e8f0"; font.pixelSize: 10; font.family: "Consolas, Monaco, monospace" }
                        Text { text: "loss";   color: "#64748b"; font.pixelSize: 10 }
                        Text {
                            text: netStatsPanel._fmt(s.packetLoss || 0) + " %"
                            color: (s.packetLoss || 0) > 0.05 ? "#f87171" : "#e2e8f0"
                            font.pixelSize: 10
                            font.family: "Consolas, Monaco, monospace"
                        }
                        Text { text: "sent";   color: "#64748b"; font.pixelSize: 10 }
                        Text { text: netStatsPanel._fmt(s.sentBwKbps) + " kbps"; color: "#e2e8f0"; font.pixelSize: 10; font.family: "Consolas, Monaco, monospace" }
                        Text { text: "recv";   color: "#64748b"; font.pixelSize: 10 }
                        Text { text: netStatsPanel._fmt(s.recvBwKbps) + " kbps"; color: "#e2e8f0"; font.pixelSize: 10; font.family: "Consolas, Monaco, monospace" }
                        Text { text: "acked";  color: "#64748b"; font.pixelSize: 10 }
                        Text { text: netStatsPanel._fmt(s.ackedBwKbps) + " kbps"; color: "#e2e8f0"; font.pixelSize: 10; font.family: "Consolas, Monaco, monospace" }
                        Text { text: "pkts";   color: "#64748b"; font.pixelSize: 10 }
                        Text {
                            text: (s.packetsSent || 0) + "↑ / " + (s.packetsAcked || 0) + "✓"
                            color: "#e2e8f0"
                            font.pixelSize: 10
                            font.family: "Consolas, Monaco, monospace"
                        }
                        Text { text: "frag";   color: "#64748b"; font.pixelSize: 10 }
                        Text {
                            text: (s.fragmentsSent || 0) + "↑ / " + (s.fragmentsReceived || 0) + "↓"
                            color: "#e2e8f0"
                            font.pixelSize: 10
                            font.family: "Consolas, Monaco, monospace"
                        }
                    }
                }
            }

            Text {
                visible: Object.keys(netStatsPanel.snapshots).length === 0
                text: "Aucun pair P2P connecté."
                color: "#64748b"
                font.pixelSize: 10
                font.italic: true
            }
        }
    }
}
