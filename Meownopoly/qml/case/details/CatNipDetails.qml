import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatNip

ColumnLayout {
    spacing: 5

    required property CaseCatNip caseData
    
    Text {
        text: "Chance"
        font.pixelSize: 16
        color: "#2c3e50"
        font.bold: true
    }

    Text {
        text: "Draw a chance card when you land here"
        font.pixelSize: 14
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "These cards can affect your movement, money, or give special abilities!"
        font.pixelSize: 12
        color: "#7f8c8d"
        Layout.topMargin: 5
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 