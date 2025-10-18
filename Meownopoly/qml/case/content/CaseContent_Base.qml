import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: caseContentBase
    width: 640
    height: 640
    color: "#00000000"
    border.color: outerCircleColor
    border.width: 3
    radius: width
    property color tileColor: "#199c3a"

    property alias icon: icon
    property alias iconSource: icon.source

    property alias nameText: nameText

    property color innerCircleColor: Qt.rgba(lighterInnerColor.r, lighterInnerColor.g, lighterInnerColor.b, 0.35)
    property color outerCircleColor: Qt.rgba(lighterOuterColor.r, lighterOuterColor.g, lighterOuterColor.b, 0.4)

    readonly property color lighterInnerColor:  Qt.lighter(tileColor, 1.2)
    readonly property color lighterOuterColor:  Qt.lighter(tileColor, 1.5)

    property var tileIcons:""
    property var fallbackIcons: "📦❓"


    Rectangle {
        id: innerCircle
        anchors.fill: parent
        anchors.margins: caseContentBase.border.width
        color: "#00000000"
        border.color: innerCircleColor
        border.width: 12
        radius: width
    }
    Rectangle {
        id: outerCircle
        anchors.fill: innerCircle
        anchors.margins: innerCircle.border.width
        color: "#00000000"
        border.color: outerCircleColor
        border.width: 3
        radius: width

    }

    Image {
        id: icon

        width: parent.width * 0.70
        height: width

        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true  // Enable mipmapping for better quality when scaling down
        antialiasing: true
        visible:status === Image.Ready
        asynchronous: true
        cache: true  // Cache the image to prevent reloading
        source: tileIcons


        // Use fixed sourceSize to prevent reloading on resize
        sourceSize {
            width: 512  // Fixed size for better performance
            height: 512
        }

        onStatusChanged: {
            if (status === Image.Error) {
                fallbackText.visible = true
            }
        }
    }

    Text {
        id: nameText
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        text: "no name"
        color: "#2c3e50"
        font.pixelSize: Math.min(parent.width * 0.13, 11)
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        width: parent.width
        z: 1
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
        text: fallbackIcons
        font.pixelSize: parent.width * 0.25
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        visible: !icon.visible
    }
}
