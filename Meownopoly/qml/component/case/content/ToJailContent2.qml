import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseToJail
import "../"
import AssetManager

CaseContent_Base {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseToJail caseData
    tileColor: "darkred"
    // Icons for different tile types
    tileIcons:AssetManager.getAssetById("ui", "case", "tojail").path
    nameText.text:  root.caseData.name
    
    nameText.anchors.horizontalCenter: root.horizontalCenter
    nameText.anchors.top: root.top

    fallbackIcons: "➡️🔒"

    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: parent.height * 0.02
        }
        visible: true
        text: "Go to Jail"
        color: "#e74c3c"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }


} 
