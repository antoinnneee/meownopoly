import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import "../"

Item {
    id: root
    anchors.fill:parent

    clip: true
    required property CaseRestArea caseData

    // Icons for different tile types
    property var tileIcons: "qrc:/asset/bed.png"          // 1: Rest Area

    property var fallbackIcons: "🛌"          // 1: Rest Area


    Text {
        id: nameText
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
        }
        text: root.caseData.name
        color: "#2c3e50"
        font.pixelSize: Math.min(parent.width * 0.13, 11)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        width: parent.width
        z: 1
    }

    StarRating {
        id: starRating
        anchors {
            top: nameText.bottom
            topMargin: - nameText.height/3
            left: parent.left
            right: parent.right
        }
        Rectangle{
            anchors.fill: parent
            color: "red"
            visible: false
        }

        height: parent.height * 0.2 + nameText.height
        visible: root.caseData.type === 1
        restQuality: root.caseData && root.caseData.restQuality ? root.caseData.restQuality : 0
        z: 2
    }

    Image {
        id: icon
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: root.caseData.type === 1 ? parent.height * 0.1 : parent.height * 0.1
        }
        width: parent.width * (root.caseData.type === 1 ? 0.8 : 0.8)
        height: width
        source: root.caseData.type >= 0 && root.caseData.type < tileIcons.length ? tileIcons : ""
        sourceSize {
            width: width * 2  // Request a larger source image for better scaling
            height: height * 2
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true  // Enable mipmapping for better quality when scaling down
        antialiasing: true
        visible: status === Image.Ready
        asynchronous: true

        onStatusChanged: {
            if (status === Image.Error) {
                fallbackText.visible = true
            }
        }
    }

    Text {
        id: fallbackText
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: nameText.bottom
            topMargin: 2
        }
        width: parent.width * 0.4
        height: width
        text: root.caseData.type >= 0 && root.caseData.type < fallbackIcons.length ? fallbackIcons : "?"
        font.pixelSize: parent.width * 0.25
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: !icon.visible
    }

    Text {
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: parent.height * 0.02
        }
        visible: root.caseData.type === 1 && root.caseData && root.caseData.price
        text: visible ? root.caseData.price + "K" : ""
        color: "#2c3e50"
        font.pixelSize: parent.width * 0.12
    }
}
