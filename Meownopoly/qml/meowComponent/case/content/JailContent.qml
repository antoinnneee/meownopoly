import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseJail
import "../"
import AssetManager

Item {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseJail caseData

    // Icons for different tile types
    property var tileIcons:AssetManager.getAssetById("ui", "case", "jail").path

    property var fallbackIcons: "🔒"

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
            top: nameText.bottom
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
        text: "Prison"
        color: "#e74c3c"
        font.pixelSize: parent.width * 0.10
        font.bold: true
    }

    Component.onCompleted: {
    }
} 
