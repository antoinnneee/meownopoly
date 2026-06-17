import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatNip
import theme

ColumnLayout {
    spacing: Theme.spacingXS

    required property CaseCatNip caseData

    Text {
        text: "Chance"
        font.pixelSize: Theme.fontSizeLarge
        color: "#2c3e50"
        font.bold: true
    }

    Text {
        text: "Draw a chance card when you land here"
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "These cards can affect your movement, money, or give special abilities!"
        font.pixelSize: Theme.fontSizeBody
        color: "#7f8c8d"
        Layout.topMargin: Theme.spacingXS
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 