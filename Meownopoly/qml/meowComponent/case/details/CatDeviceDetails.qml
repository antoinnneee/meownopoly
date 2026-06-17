import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatDevice
import theme

ColumnLayout {
    spacing: Theme.spacingXS

    required property CaseCatDevice caseData

    Text {
        text: "Water Fountain"
        font.pixelSize: Theme.fontSizeLarge
        color: "#2980b9"
        font.bold: true
    }

    Text {
        text: "Owner: " + (caseData && caseData.owner ? caseData.owner : "None")
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
    }

    Text {
        text: "A refreshing utility service for all cats"
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "Rent is based on dice roll and how many utilities the owner controls."
        font.pixelSize: Theme.fontSizeBody
        color: "#7f8c8d"
        Layout.topMargin: Theme.spacingXS
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 