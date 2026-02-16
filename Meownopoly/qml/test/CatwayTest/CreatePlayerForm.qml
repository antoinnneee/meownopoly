import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0

Rectangle {
    id: createPlayerFormRoot
    required property var host
    required property Component playerComponent

    /// Joueur en cours d'édition (null = mode création).
    property var editingPlayer: null

    function setPlayer(playerId, nickname) {
        fieldPlayerId.text = playerId || ""
        fieldNickname.text = nickname || ""
        editingPlayer = null
    }

    function loadPlayer(player) {
        if (!player) return
        editingPlayer = player
        fieldPlayerId.text = player.playerId || ""
        fieldNickname.text = player.nickname || ""
        fieldDestIp.text = player.ip || ""
        fieldDestPort.text = player.port ? String(player.port) : ""
        host.selectedSocketInfo = player.socketInfo || null
        host.selectedPortIndex = -1
    }

    function clearForm() {
        editingPlayer = null
        fieldPlayerId.clear()
        fieldNickname.clear()
        fieldDestIp.clear()
        fieldDestPort.clear()
        host.selectedSocketInfo = null
        host.selectedPortIndex = -1
    }

    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1
    implicitHeight: createColumn.implicitHeight + 24

    ColumnLayout {
        id: createColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
            text: editingPlayer ? "Modifier le joueur" : "Créer un joueur"
            color: host.textPrimary
            font.pixelSize: 15
            font.bold: true
        }

        ColumnLayout {
            spacing: 4
            Text { text: "Player ID"; color: host.textSecondary; font.pixelSize: 11; font.capitalization: Font.AllUppercase }
            TextField {
                id: fieldPlayerId
                placeholderText: "ex: player_1"
                placeholderTextColor: "#71717a"
                font.pixelSize: 13
                implicitHeight: 38
                background: Rectangle {
                    color: "#222226"
                    radius: 6
                    border.color: fieldPlayerId.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldPlayerId.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            spacing: 4
            Text { text: "Nickname"; color: host.textSecondary; font.pixelSize: 11; font.capitalization: Font.AllUppercase }
            TextField {
                id: fieldNickname
                placeholderText: "ex: Minou"
                placeholderTextColor: "#71717a"
                font.pixelSize: 13
                implicitHeight: 38
                background: Rectangle {
                    color: "#222226"
                    radius: 6
                    border.color: fieldNickname.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldNickname.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            spacing: 4
            Text { text: "Socket"; color: host.textSecondary; font.pixelSize: 11; font.capitalization: Font.AllUppercase }
            RowLayout {
                spacing: 8
                Button {
                    text: "Socket actuel"
                    implicitHeight: 36
                    font.pixelSize: 12
                    background: Rectangle {
                        color: parent.pressed ? "#2d2d35" : "transparent"
                        radius: 6
                        border.color: host.cardBorder
                        border.width: 1
                    }
                    contentItem: Text {
                        text: parent.text
                        color: host.textPrimary
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        host.selectedPortIndex = -1
                        host.selectedSocketInfo = Catway.currentSocketInfo()
                    }
                }
                Text {
                    color: host.textSecondary
                    font.pixelSize: 11
                    text: host.selectedSocketInfo ? (host.selectedSocketInfo.publicAddress + ":" + host.selectedSocketInfo.publicPort) : "— non choisi —"
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
            }
        }

        ColumnLayout {
            spacing: 4
            Text { text: "Destination (IP)"; color: host.textSecondary; font.pixelSize: 11; font.capitalization: Font.AllUppercase }
            TextField {
                id: fieldDestIp
                placeholderText: "ex: 78.122.112.36"
                placeholderTextColor: "#71717a"
                font.pixelSize: 13
                implicitHeight: 38
                background: Rectangle {
                    color: "#222226"
                    radius: 6
                    border.color: fieldDestIp.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldDestIp.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
            }
        }

        ColumnLayout {
            spacing: 4
            Text { text: "Destination (port)"; color: host.textSecondary; font.pixelSize: 11; font.capitalization: Font.AllUppercase }
            TextField {
                id: fieldDestPort
                placeholderText: "ex: 55413"
                placeholderTextColor: "#71717a"
                font.pixelSize: 13
                implicitHeight: 38
                inputMethodHints: Qt.ImhDigitsOnly
                validator: IntValidator { bottom: 1; top: 65535 }
                background: Rectangle {
                    color: "#222226"
                    radius: 6
                    border.color: fieldDestPort.activeFocus ? host.accent : host.cardBorder
                    border.width: fieldDestPort.activeFocus ? 2 : 1
                }
                color: host.textPrimary
                Layout.fillWidth: true
            }
        }

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            visible: !!Catway.chatClient
            Button {
                text: "Demander infos connexion"
                implicitHeight: 36
                font.pixelSize: 12
                enabled: !!(host.selectedSocketInfo || Catway.currentSocketInfo()) && fieldPlayerId.text.trim().length > 0
                background: Rectangle {
                    color: parent.enabled ? (parent.pressed ? "#2d2d35" : "transparent") : "#1a1a1e"
                    radius: 6
                    border.color: host.cardBorder
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: parent.enabled ? host.textPrimary : host.textSecondary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var pid = fieldPlayerId.text.trim()
                    var info = host.selectedSocketInfo || Catway.currentSocketInfo()
                    if (!Catway.chatClient || !info || pid.length === 0)
                        return
                    var ip = info.publicAddress || ""
                    var port = info.publicPort || 0
                    Catway.chatClient.sendRequestConnectionInfo(pid, ip, port)
                }
            }
            Text {
                text: "Player ID requis + socket choisi."
                color: host.textSecondary
                font.pixelSize: 11
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
            }
        }

        RowLayout {
            spacing: 8
            Layout.topMargin: 2
            Button {
                text: editingPlayer ? "Modifier le joueur" : "Ajouter le joueur"
                implicitHeight: 40
                font.pixelSize: 13
                font.bold: true
                Layout.fillWidth: true
                background: Rectangle {
                    color: parent.pressed ? Qt.darker(host.accent, 1.2) : (parent.hovered ? host.accentHover : host.accent)
                    radius: 8
                }
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: {
                    var info = host.selectedSocketInfo
                    if (!info)
                        info = Catway.currentSocketInfo()
                    if (editingPlayer) {
                        editingPlayer.playerId = fieldPlayerId.text.trim() || editingPlayer.playerId
                        editingPlayer.nickname = fieldNickname.text.trim() || "Joueur"
                        editingPlayer.socketInfo = info
                        editingPlayer.ip = fieldDestIp.text.trim()
                        var portVal = parseInt(fieldDestPort.text, 10)
                        editingPlayer.port = (portVal >= 1 && portVal <= 65535) ? portVal : 0
                        clearForm()
                    } else {
                        var p = playerComponent.createObject(host)
                        if (p) {
                            p.playerId = fieldPlayerId.text.trim() || ("id_" + Date.now())
                            p.nickname = fieldNickname.text.trim() || "Joueur"
                            p.socketInfo = info
                            p.ip = fieldDestIp.text.trim()
                            var portVal = parseInt(fieldDestPort.text, 10)
                            p.port = (portVal >= 1 && portVal <= 65535) ? portVal : 0
                            Catway.addPlayer(p)
                            clearForm()
                        }
                    }
                }
            }
            Button {
                text: "Nouveau"
                implicitHeight: 40
                font.pixelSize: 12
                visible: !!editingPlayer
                background: Rectangle {
                    color: parent.pressed ? "#2d2d35" : "transparent"
                    radius: 8
                    border.color: host.cardBorder
                    border.width: 1
                }
                contentItem: Text {
                    text: parent.text
                    color: host.textPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                onClicked: clearForm()
            }
        }
    }
}
