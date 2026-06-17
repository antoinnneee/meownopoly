import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCardBoardBox
import theme

ColumnLayout {
    spacing: Theme.spacingXS

    required property CaseCardBoardBox caseData

    Text {
        text: "Community Chest"
        font.pixelSize: Theme.fontSizeLarge
        color: "#2c3e50"
        font.bold: true
    }

    Text {
        text: "Draw a community chest card when you land here"
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "These cards can give you rewards, penalties, or special actions!"
        font.pixelSize: Theme.fontSizeBody
        color: "#7f8c8d"
        Layout.topMargin: Theme.spacingXS
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 