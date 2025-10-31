import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseToJail

ColumnLayout {
    spacing: 5

    required property CaseToJail caseData
    
    Text {
        text: "Go to Jail"
        font.pixelSize: 16
        color: "#e74c3c"
        font.bold: true
    }

    Text {
        text: "Go directly to jail. Do not pass GO, do not collect 200K."
        font.pixelSize: 14
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "You must stay in jail until you roll doubles, pay a fine, or use a Get Out of Jail Free card."
        font.pixelSize: 12
        color: "#7f8c8d"
        Layout.topMargin: 5
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 