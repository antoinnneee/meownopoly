import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatDevice

ColumnLayout {
    spacing: 5

    required property CaseCatDevice caseData
    
    Text {
        text: "Water Fountain"
        font.pixelSize: 16
        color: "#2980b9"
        font.bold: true
    }

    Text {
        text: "Owner: " + (caseData && caseData.owner ? caseData.owner : "None")
        font.pixelSize: 14
        color: "#2c3e50"
    }

    Text {
        text: "A refreshing utility service for all cats"
        font.pixelSize: 14
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "Rent is based on dice roll and how many utilities the owner controls."
        font.pixelSize: 12
        color: "#7f8c8d"
        Layout.topMargin: 5
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 