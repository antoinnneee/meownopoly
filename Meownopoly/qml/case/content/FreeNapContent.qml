import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseFreeNap
import "../"

Item {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseFreeNap caseData

    // Icons for different tile types
    property var tileIcons: "qrc:/asset/nap.png"

    property var fallbackIcons: "😴"

    Image {
        id: icon
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
            verticalCenterOffset: parent.height * 0.1
        }
        width: parent.width * 0.8
        height: width
        source: root.tileIcons
        sourceSize {
            width: width * 2
            height: height * 2
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
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
            topMargin: 2
        }
        width: parent.width * 0.4
        height: width
        text: root.fallbackIcons
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
        text: root.caseData.name
        color: "#27ae60"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }

    Component.onCompleted: {
        console.log("FreeNapContent loaded");
    }
} 
