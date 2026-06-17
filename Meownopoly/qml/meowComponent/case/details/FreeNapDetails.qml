import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseFreeNap
import theme

ColumnLayout {
    spacing: Theme.spacingXS

    required property CaseFreeNap caseData

    Text {
        text: "Free Nap"
        font.pixelSize: Theme.fontSizeLarge
        color: "#27ae60"
        font.bold: true
    }

    Text {
        text: "A peaceful spot to rest and relax"
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "Take a break from the game - no rewards or penalties here!"
        font.pixelSize: Theme.fontSizeBody
        color: "#7f8c8d"
        Layout.topMargin: Theme.spacingXS
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 