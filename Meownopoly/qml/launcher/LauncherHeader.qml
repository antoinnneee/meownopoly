import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme
import ui_item

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

        MeowButton {
            text: "Retour"
            variant: "danger"
            fontSize: Theme.fontSizeBody
            onClicked: root.backRequested()
        }
    }
}
