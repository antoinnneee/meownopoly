import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatDoor
import "../"
import AssetManager

CaseContent_Base {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseCatDoor caseData
    tileColor: "lightgrey"
    // Icons for different tile types
    tileIcons: AssetManager.getAssetById("ui", "case", "catdoor").path

    fallbackIcons: "🚪"
    nameText.text:  root.caseData.name

    nameText.anchors.horizontalCenter: root.horizontalCenter
    nameText.anchors.top: root.top

    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: parent.height * 0.02
        }
        visible: true
        text: "Train Station"
        color: "#3498db"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }

} 
