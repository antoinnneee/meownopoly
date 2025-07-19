import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatDoor

ColumnLayout {
    spacing: 5

    required property CaseCatDoor caseData
    
    Text {
        text: "Train Station"
        font.pixelSize: 16
        color: "#3498db"
        font.bold: true
    }

    Text {
        text: "Owner: " + (caseData && caseData.owner ? caseData.owner : "None")
        font.pixelSize: 14
        color: "#2c3e50"
    }

    Text {
        text: "A convenient way to travel around the board!"
        font.pixelSize: 14
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "Rent depends on how many train stations the owner controls."
        font.pixelSize: 12
        color: "#7f8c8d"
        Layout.topMargin: 5
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 