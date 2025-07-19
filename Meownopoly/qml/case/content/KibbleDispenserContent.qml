import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseKibbleDispenser
import "../"

Item {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseKibbleDispenser caseData

    // Icons for different tile types
    property var tileIcons:  "qrc:/asset/kibble.png"         // 1: Rest Area

    property var fallbackIcons: "🐱💰"          // 1: Rest Area


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

    Image {
        id: icon
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset:  parent.height * 0.1
        }
        width: parent.width * 0.8
        height: width
        source:  root.tileIcons
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
        text:root.fallbackIcons
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
        visible: true
        text: visible ? root.caseData.reward + "K" : ""
        color: "#2c3e50"
        font.pixelSize: parent.width * 0.12
    }
    Component.onCompleted: {
        console.log("KibbleDispenserContent loaded");
    }
}
