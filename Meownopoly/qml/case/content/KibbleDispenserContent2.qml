import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseKibbleDispenser
import "../"
import AssetManager

CaseContent_Base {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseKibbleDispenser caseData
    tileColor: "lightgrey"

    // Icons for different tile types
    tileIcons: AssetManager.getAssetPath("ui", "case", "kibble")
    fallbackIcons: "🐱💰"

    nameText.text:  root.caseData.name

    nameText.anchors.horizontalCenter: parent.horizontalCenter
    nameText.anchors.top: parent.top


   

    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: parent.height * 0.02
        }
        visible: true
        text: visible ? root.caseData.reward + "K" : ""
        color: "#2c3e50"
        font.pixelSize: parent.width * 0.12
    }
}
