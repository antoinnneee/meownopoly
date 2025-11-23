import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCardBoardBox
import AssetManager
import "../"

CaseContent_Base {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseCardBoardBox caseData

    tileColor: "lightgrey"
    // Icons for different tile types
    tileIcons: AssetManager.getAssetById("ui", "case", "cardboard").path

    fallbackIcons: "📦❓"

    nameText.text:  root.caseData.name


    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: parent.height * 0.02
        }
        visible: true
        text: "Draw Card"
        color: "#2c3e50"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }

    Component.onCompleted: {
    }
} 
