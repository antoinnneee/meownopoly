import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseKibbleDispenser
import theme

ColumnLayout {
    spacing: Theme.spacingXS

    required property CaseKibbleDispenser caseData
    Text {
        text: "Collect " + ((caseData)?caseData.reward  : "" )+ "K when passing"
        font.pixelSize: Theme.fontSizeMedium
        color: "#2c3e50"
        font.bold: true
    }

    Text {
        text: "Start your journey here!"
        font.pixelSize: Theme.fontSizeBody
        color: "#7f8c8d"
        Layout.topMargin: Theme.spacingXS
    }
} 
