/*
 * PhysicsNetworkPanel — Phase 7 (state-sync host-authoritative).
 *
 * Petit badge top-right (sous MultiActorTestPanel) qui :
 *  - démarre PhysicsSession en HOST ou en CLIENT
 *  - affiche le rôle courant + un compteur snapshots émis/reçus
 *
 * Pré-requis pour le client : avoir un peer P2P connecté côté Catway dont le
 * playerId sera pré-rempli ; sinon saisir manuellement.
 *
 * Usage typique (test dual_test_p2p) :
 *   Instance 1 → Hôte. Editor + multi-actor ON → P1 (ZQSD), P2 (flèches).
 *   Instance 2 → Client (avec hostPlayerId = id de l'instance 1).
 *      Sur l'instance 2, le clavier flèches contrôle player2 via InputUpdate
 *      reliable ; les positions sont visibles en quasi-temps réel.
 */
import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Pattounx 1.0
import Catway 1.0
import Meownopoly.Account 1.0

Item {
    id: root

    // Placement dans la Column `leftBadgeStack` d'Editor.qml.
    width: open ? expanded.width : badge.width
    height: open ? expanded.height : badge.height

    property bool open: false

    // Pré-remplissage du host playerId via le 1er peer P2P connecté connu de
    // Catway. À tout moment, l'utilisateur peut écraser dans le TextField.
    function _firstConnectedPeerId() {
        if (!Catway || Catway.playersCount() === 0) return ""
        for (let i = 0; i < Catway.playersCount(); ++i) {
            const p = Catway.playerAt(i)
            if (p && p.p2pConnected) return p.playerId
        }
        return ""
    }

    // ─── Badge replié ─────────────────────────────────────────────────────────
    Rectangle {
        id: badge
        visible: !root.open
        width: badgeContent.implicitWidth + 20
        height: badgeContent.implicitHeight + 10
        radius: 6
        color: PhysicsSession.active
                ? (PhysicsSession.isHost ? "#1e3a5f" : "#3a5f1e")
                : "#2a2a2e"
        border.color: PhysicsSession.active
                ? (PhysicsSession.isHost ? "#3b82f6" : "#84cc16")
                : "#71717a"
        border.width: 1

        Row {
            id: badgeContent
            anchors.centerIn: parent
            spacing: 8
            Rectangle {
                width: 10; height: 10; radius: 5
                anchors.verticalCenter: parent.verticalCenter
                color: PhysicsSession.active
                        ? (PhysicsSession.isHost ? "#3b82f6" : "#84cc16")
                        : "#71717a"
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: PhysicsSession.active
                        ? (PhysicsSession.isHost
                                ? ("NET · HOST · " + PhysicsSession.snapshotsSent + "↑")
                                : ("NET · CLIENT · " + PhysicsSession.snapshotsReceived + "↓"))
                        : "NET · OFF"
                color: "#f4f4f5"
                font.pixelSize: 12
                font.bold: true
            }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open = true
        }
    }

    // ─── Panel déplié ─────────────────────────────────────────────────────────
    Rectangle {
        id: expanded
        visible: root.open
        width: 260
        height: contentColumn.implicitHeight + 24
        radius: 8
        color: "#1c1c20"
        border.color: "#71717a"
        border.width: 1

        // Button stylé sombre/lisible — évite que le style Material par défaut
        // tronque le label sur les petits boutons du panel.
        component PillBtn: Button {
            id: btn
            implicitHeight: 26
            padding: 4
            leftPadding: 8; rightPadding: 8
            contentItem: Text {
                text: btn.text
                color: btn.enabled ? "#f4f4f5" : "#71717a"
                font.pixelSize: 11
                font.bold: true
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
            background: Rectangle {
                color: btn.pressed ? "#3f3f46" : (btn.hovered ? "#33333a" : "#2a2a2e")
                radius: 4
                border.color: "#52525b"
                border.width: 1
                opacity: btn.enabled ? 1.0 : 0.5
            }
        }

        ColumnLayout {
            id: contentColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Physics Network (Phase 7)"
                    color: "#f4f4f5"
                    font.bold: true
                    font.pixelSize: 13
                }
                Button {
                    text: "×"
                    flat: true
                    implicitWidth: 24
                    implicitHeight: 24
                    contentItem: Text {
                        text: parent.text
                        color: "#a1a1aa"
                        font.pixelSize: 16
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Item {}
                    onClicked: root.open = false
                }
            }

            Text {
                text: "Mon playerId (auto)"
                color: "#a1a1aa"; font.pixelSize: 10
            }
            TextField {
                id: localIdField
                Layout.fillWidth: true
                placeholderText: "playerId local"
                text: AccountManager ? AccountManager.uniqueId : ""
                font.pixelSize: 11
                color: "#f4f4f5"
                background: Rectangle { color: "#0e0e13"; radius: 4; border.color: "#3f3f46"; border.width: 1 }
            }

            Text {
                text: "playerId de l'hôte (si client)"
                color: "#a1a1aa"; font.pixelSize: 10
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 4
                TextField {
                    id: hostIdField
                    Layout.fillWidth: true
                    placeholderText: "hostPlayerId"
                    font.pixelSize: 11
                    color: "#f4f4f5"
                    background: Rectangle { color: "#0e0e13"; radius: 4; border.color: "#3f3f46"; border.width: 1 }
                }
                PillBtn {
                    text: "↓"
                    implicitWidth: 28
                    ToolTip.visible: hovered
                    ToolTip.text: "Pré-remplir avec le 1er peer P2P connecté"
                    onClicked: {
                        const pid = root._firstConnectedPeerId()
                        if (pid) hostIdField.text = pid
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                PillBtn {
                    Layout.fillWidth: true
                    text: "HOST"
                    enabled: !PhysicsSession.active
                    onClicked: PhysicsSession.startAsHost(localIdField.text)
                }
                PillBtn {
                    Layout.fillWidth: true
                    text: "CLIENT"
                    enabled: !PhysicsSession.active && hostIdField.text.length > 0
                    onClicked: {
                        // Pré-remplir le claim si l'utilisateur n'a rien
                        // saisi explicitement — par défaut, on contrôle "player2"
                        // (P1 reste à l'host).
                        if (claimField.text.length === 0)
                            claimField.text = "player2"
                        PhysicsSession.claimedActorId = claimField.text
                        PhysicsSession.startAsClient(localIdField.text, hostIdField.text)
                    }
                }
                PillBtn {
                    Layout.fillWidth: true
                    text: "STOP"
                    enabled: PhysicsSession.active
                    onClicked: PhysicsSession.stop()
                }
            }

            Text {
                text: "Acteur revendiqué (client)"
                color: "#a1a1aa"; font.pixelSize: 10
            }
            TextField {
                id: claimField
                Layout.fillWidth: true
                placeholderText: "ex: player2 — vide = pas de filtre"
                text: PhysicsSession.claimedActorId
                onEditingFinished: PhysicsSession.claimedActorId = text
                font.pixelSize: 11
                color: "#f4f4f5"
                background: Rectangle { color: "#0e0e13"; radius: 4; border.color: "#3f3f46"; border.width: 1 }
            }

            PillBtn {
                Layout.fillWidth: true
                visible: PhysicsSession.active && PhysicsSession.isHost
                text: "Spawn body 'player2'"
                ToolTip.visible: hovered
                ToolTip.text: "Crée un Kinematic actor 'player2' côté hôte (à utiliser si multi-actor OFF)."
                onClicked: pattounxWorld.createKinematicActor(
                    "player2", Qt.vector2d(2, 0), 0.2,
                    ({ acceleration: 30.0, maxSpeed: 30.0, linearDamping: 0.1 }))
            }

            // Statut session
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                Rectangle {
                    width: 10; height: 10; radius: 5
                    color: PhysicsSession.active
                            ? (PhysicsSession.isHost ? "#3b82f6" : "#84cc16")
                            : "#71717a"
                }
                Text {
                    Layout.fillWidth: true
                    text: PhysicsSession.active
                            ? (PhysicsSession.isHost ? "HOST" : "CLIENT")
                            : "Inactif"
                    color: "#f4f4f5"
                    font.pixelSize: 11
                }
                Text {
                    text: PhysicsSession.snapshotHz + " Hz"
                    color: "#a1a1aa"
                    font.pixelSize: 10
                }
            }

            Text {
                visible: PhysicsSession.active
                text: PhysicsSession.isHost
                        ? ("Snapshots envoyés : " + PhysicsSession.snapshotsSent)
                        : ("Snapshots reçus : " + PhysicsSession.snapshotsReceived
                           + "\nTick remote : " + (pattounxWorld ? pattounxWorld.currentGuiTick() : 0))
                color: "#a1a1aa"
                font.pixelSize: 10
                font.family: "monospace"
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }

            PillBtn {
                Layout.fillWidth: true
                visible: PhysicsSession.active && PhysicsSession.isHost
                text: "Re-broadcast table complète"
                ToolTip.visible: hovered
                ToolTip.text: "Envoie la full table d'idIndex à tous les pairs (utile si un client a manqué des announces)"
                onClicked: PhysicsSession.broadcastFullBodyTable()
            }
        }
    }
}
