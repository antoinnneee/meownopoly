import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseFreeNap

ColumnLayout {
    spacing: 5

    required property CaseFreeNap caseData
    
    Text {
        text: "Free Nap"
        font.pixelSize: 16
        color: "#27ae60"
        font.bold: true
    }

    Text {
        text: "A peaceful spot to rest and relax"
        font.pixelSize: 14
        color: "#2c3e50"
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }

    Text {
        text: "Take a break from the game - no rewards or penalties here!"
        font.pixelSize: 12
        color: "#7f8c8d"
        Layout.topMargin: 5
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
    }
} 