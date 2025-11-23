import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseJail
import "../"
import AssetManager

CaseContent_Base {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseJail caseData
    property bool catInJail: true
    tileColor: "darkred"
    // Icons for different tile types
    tileIcons: (catInJail) ?  AssetManager.getAssetById("ui", "case", "jail").path : AssetManager.getAssetById("ui", "case", "jail_noCat").path

    fallbackIcons: "🔒"
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
        text: "Prison"
        color: "#e74c3c"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }

} 
