import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseCatDevice
import "../"
import AssetManager
Item {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseCatDevice caseData

    // Icons for different tile types
    property var tileIcons: AssetManager.getAssetById("ui", "case", "laser").path

    property var fallbackIcons: "💧"

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
        // Use fixed sourceSize to prevent reloading on resize
        sourceSize {
            width: 512  // Fixed size for better performance
            height: 512
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
        color: "#2980b9"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }

    Component.onCompleted: {
    }
} 
