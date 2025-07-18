import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseKibbleDispenser

ColumnLayout {
    spacing: 5

    required property CaseKibbleDispenser caseData
    Text {
        text: "Collect " + caseData.reward + "K when passing"
        font.pixelSize: 14
        color: "#2c3e50"
        font.bold: true
    }

    Text {
        text: "Start your journey here!"
        font.pixelSize: 12
        color: "#7f8c8d"
        Layout.topMargin: 5
    }
} 
