import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme

Rectangle {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 80
    color: Theme.border
    radius: Theme.radiusXXL
    border.color: Theme.borderLight
    border.width: 1

    signal backRequested()

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingHuge

        Text {
            text: "🐱 Meownopoly Resource Launcher"
            font.pixelSize: Theme.fontSizeDisplay
            font.bold: true
            color: Theme.textPrimary
        }

        Item { Layout.fillWidth: true }

        Button {
            text: "Retour"
            onClicked: root.backRequested()

            background: Rectangle {
                color: parent.pressed ? Theme.pressed(Theme.danger) : Theme.danger
                radius: Theme.radiusM
            }

            contentItem: Text {
                text: parent.text
                color: Theme.textPrimary
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
