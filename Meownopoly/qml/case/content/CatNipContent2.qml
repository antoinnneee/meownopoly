import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatNip
import "../"
import AssetManager

CaseContent_Base {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseCatNip caseData

    tileColor: "lightgrey"
    // Icons for different tile types
    tileIcons:AssetManager.getAssetPath("ui", "case", "catnip")

    iconSource: tileIcons
    icon.width: root.width * 0.70

    fallbackIcons: "🌿"
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
        text: "Chance"
        color: "#2c3e50"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }

} 
