import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

ColumnLayout {
    spacing: Theme.spacingXS

    Text {
        text: "Jail Time: 3 turns"
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
        font.bold: true
    }

    Text {
        text: "To get out:"
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
        Layout.topMargin: Theme.spacingXS
    }

    Text {
        text: "• Roll doubles\n• Pay 50K fine\n• Use 'Get Out of Jail Free' card"
        font.pixelSize: Theme.fontSizeBody
        color: "#7f8c8d"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.leftMargin: Theme.spacingL
    }
} 