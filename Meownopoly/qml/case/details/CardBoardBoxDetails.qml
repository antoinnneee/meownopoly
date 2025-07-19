import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCardBoardBox

ColumnLayout {
    spacing: 5

    required property CaseCardBoardBox caseData
    
    Text {
        text: "Community Chest"
        font.pixelSize: 16
        color: "#2c3e50"
        font.bold: true
    }

    Text {
        text: "Draw a community chest card when you land here"
        font.pixelSize: 14
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "These cards can give you rewards, penalties, or special actions!"
        font.pixelSize: 12
        color: "#7f8c8d"
        Layout.topMargin: 5
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 