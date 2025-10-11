import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatDevice
import "../"
import AssetManager
CaseContent_Base {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseCatDevice caseData
    tileColor: "lightblue"
    // Icons for different tile types
    tileIcons: AssetManager.getAssetPath("ui", "case", "laser")

    fallbackIcons: "💧"

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
        text: root.caseData.name
        color: "#2980b9"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }

} 
