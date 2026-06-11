import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Catway 1.0
import theme

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
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingL

        Text {
            text: "Port STUN"
            color: host.textPrimary
            font.pixelSize: Theme.fontSizeMedium
            font.bold: true
        }
        Button {
            text: "Nouveau port STUN"
            implicitHeight: 40
            font.pixelSize: Theme.fontSizeBody
            background: Rectangle {
                color: parent.pressed ? Qt.darker(host.accent, 1.2) : (parent.hovered ? host.accentHover : host.accent)
                radius: Theme.radiusL
            }
            contentItem: Text {
                text: parent.text
                color: Theme.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: Catway.setupNewPort()
        }
    }
}
