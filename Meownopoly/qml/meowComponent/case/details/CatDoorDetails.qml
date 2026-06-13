import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatDoor
import theme

ColumnLayout {
    spacing: Theme.spacingXS

    required property CaseCatDoor caseData

    Text {
        text: "Train Station"
        font.pixelSize: Theme.fontSizeLarge
        color: "#3498db"
        font.bold: true
    }

    Text {
        text: "Owner: " + (caseData && caseData.owner ? caseData.owner : "None")
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
    }

    Text {
        text: "A convenient way to travel around the board!"
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "Rent depends on how many train stations the owner controls."
        font.pixelSize: Theme.fontSizeBody
        color: "#7f8c8d"
        Layout.topMargin: Theme.spacingXS
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 