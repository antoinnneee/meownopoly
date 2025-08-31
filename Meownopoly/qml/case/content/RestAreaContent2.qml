import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import "../"
import AssetManager

CaseContent_Base {
    id: root
    required property CaseRestArea caseData
    property var familyColors: []

    onFamilyColorsChanged:{
        console.log(" fam color change :", familyColors)
    }
    tileColor: root.familyColors[caseData.family]

    icon.anchors.verticalCenterOffset: colorBar.height/3
    // Icons for different tile types
    tileIcons: AssetManager.getAssetPath("ui", "case", "bed2")          // 1: Rest Area
    fallbackIcons: "🛌"          // 1: Rest Area

    nameText.text:  root.caseData.name

    Rectangle {
        id: colorBar
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
        }
        height: Math.min(Screen.pixelDensity * 10, parent.height *0.15)
        color: root.familyColors[caseData.family]
        radius: 4
        bottomLeftRadius: Screen.pixelDensity * 3
        bottomRightRadius: Screen.pixelDensity * 3
    }

    StarRating {
        id: starRating
        anchors {
            top: nameText.bottom
            topMargin: - nameText.height/3
            left: parent.left
            right: parent.right
        }

        height: parent.height * 0.2 + nameText.height
        visible: true
        restQuality:  root.caseData.restQuality
        z: 2
    }



    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: parent.height * 0.02
        }
        visible: root.caseData.type === Case.CS_RestArea && root.caseData
        text: visible ? root.caseData.price + "K" : ""
        color: "#2c3e50"
        font.pixelSize: parent.width * 0.12
    }


}
