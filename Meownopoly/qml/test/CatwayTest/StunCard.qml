import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0

Rectangle {
    required property var host

    implicitHeight: stunColumn.implicitHeight + 24
    color: host.cardBg
    radius: host.cardRadius
    border.color: host.cardBorder
    border.width: 1

    ColumnLayout {
        id: stunColumn
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Text {
            text: "Port STUN"
            color: host.textPrimary
            font.pixelSize: 15
            font.bold: true
        }
        Button {
            text: "Nouveau port STUN"
            implicitHeight: 40
            font.pixelSize: 13
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
            onClicked: Catway.setupNewPort()
        }
        RowLayout {
            spacing: 16
            RowLayout {
                spacing: 6
                Text { text: "IP:"; color: host.textSecondary; font.pixelSize: 12 }
                Text { text: Catway.getExternalIp(); color: host.textPrimary; font.pixelSize: 12 }
            }
            RowLayout {
                spacing: 6
                Text { text: "Port:"; color: host.textSecondary; font.pixelSize: 12 }
                Text { text: Catway.getExternalPort(); color: host.textPrimary; font.pixelSize: 12 }
            }
        }
    }
}
