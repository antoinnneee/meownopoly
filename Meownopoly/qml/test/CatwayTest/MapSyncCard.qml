import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GameSession 1.0

Rectangle {
    id: root
    required property var host

    property alias lastMapSyncSenderText: lastMapSyncSender.text
    property alias lastMapSyncSummaryText: lastMapSyncSummary.text

    Layout.fillWidth: true
    height: 180
    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Text {
            text: "Map Sync (reliable)"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: 14
        }

        TextArea {
            id: mapJsonField
            Layout.fillWidth: true
            implicitHeight: 60
            placeholderText: '{"mapName":"test","tiles":[]}'
            font.pixelSize: 12
            color: host.textPrimary
            wrapMode: Text.Wrap
            background: Rectangle {
                color: "#0e0e13"
                radius: 6
                border.color: host.cardBorder
                border.width: 1
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Envoyer MapSync"
            implicitHeight: 30
            background: Rectangle {
                color: parent.pressed ? host.accent : "#2d2d35"
                radius: 6
                border.color: host.cardBorder
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: host.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: 12
            }
            onClicked: {
                try {
                    GameSession.sendMapSync(JSON.parse(mapJsonField.text))
                } catch (e) {}
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4
            Text {
                text: "Dernière reçue :"
                color: host.textSecondary
                font.pixelSize: 11
            }
            Text {
                id: lastMapSyncSender
                text: "—"
                color: host.textPrimary
                font.pixelSize: 11
                elide: Text.ElideRight
            }
            Text {
                id: lastMapSyncSummary
                text: ""
                color: host.textSecondary
                font.pixelSize: 11
            }
        }
    }
}
