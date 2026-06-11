import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import GameSession 1.0
import theme

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
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingM

        Text {
            text: "Map Sync (reliable)"
            color: host.textPrimary
            font.bold: true
            font.pixelSize: Theme.fontSizeMedium
        }

        TextArea {
            id: mapJsonField
            Layout.fillWidth: true
            implicitHeight: 60
            placeholderText: '{"mapName":"test","tiles":[]}'
            font.pixelSize: Theme.fontSizeBody
            color: host.textPrimary
            wrapMode: Text.Wrap
            background: Rectangle {
                color: Theme.background
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
            }
        }

        Button {
            Layout.fillWidth: true
            text: "Envoyer MapSync"
            implicitHeight: 30
            background: Rectangle {
                color: parent.pressed ? host.accent : Theme.surfaceAlt
                radius: Theme.radiusM
                border.color: host.cardBorder
                border.width: 1
            }
            contentItem: Text {
                text: parent.text
                color: host.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                font.pixelSize: Theme.fontSizeBody
            }
            onClicked: {
                try {
                    GameSession.sendMapSync(JSON.parse(mapJsonField.text))
                } catch (e) {}
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spacingXS
            Text {
                text: "Dernière reçue :"
                color: host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
            }
            Text {
                id: lastMapSyncSender
                text: "—"
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeSmall
                elide: Text.ElideRight
            }
            Text {
                id: lastMapSyncSummary
                text: ""
                color: host.textSecondary
                font.pixelSize: Theme.fontSizeSmall
            }
        }
    }
}
