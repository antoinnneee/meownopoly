import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 5

    Text {
        text: "Jail Time: 3 turns"
        font.pixelSize: 14
        color: "#2c3e50"
        font.bold: true
    }

    Text {
        text: "To get out:"
        font.pixelSize: 14
        color: "#2c3e50"
        Layout.topMargin: 5
    }

    Text {
        text: "• Roll doubles\n• Pay 50K fine\n• Use 'Get Out of Jail Free' card"
        font.pixelSize: 12
        color: "#7f8c8d"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.leftMargin: 10
    }
} 