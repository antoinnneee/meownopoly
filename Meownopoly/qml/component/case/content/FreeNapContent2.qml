import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseFreeNap
import "../"
import QtQuick.Effects
import AssetManager


CaseContent_Base {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseFreeNap caseData
    tileColor: "#ecd160"
    // Icons for different tile types
    tileIcons:AssetManager.getAssetPath("ui", "case", "nap2")

    fallbackIcons: "😴"
    nameText.text:  root.caseData.name

    nameText.anchors.horizontalCenter: root.horizontalCenter
    nameText.anchors.bottom: root.bottom
    nameText.anchors.bottomMargin: root.height * 0.02
    nameText.anchors.top:undefined

    nameText.color: "#27ae60"
    nameText.font.pixelSize: parent.width * 0.10
    nameText.font.bold: true
}
