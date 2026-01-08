import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseFreeNap
import "../"
import QtQuick.Effects
import AssetManager


Item {
    id: root
    anchors.fill:parent
    clip: true
    required property CaseFreeNap caseData

    // Icons for different tile types
    property string tileIcons:AssetManager.getAssetById("ui", "case", "nap2").path

    property string fallbackIcons: "😴"

    Image {
        id: icon
        anchors {
            horizontalCenter: parent.horizontalCenter
            verticalCenter: parent.verticalCenter
        }
        width: parent.width * 0.8
        height: width
        sourceSize {
            width: 512  // Fixed size for better performance
            height: 512
        }
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        antialiasing: true
        visible: status === Image.Ready
        source: tileIcons
        anchors.verticalCenterOffset: 0
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
/*
    MultiEffect {
        id: multiEffect
        source: icon
        colorization: 0
        brightness: 0.0
        Behavior on brightness {
            NumberAnimation{
                easing.bezierCurve: [0.289,0.0238,0.996,0.197,1,1]
                duration: 100
            }
        }

        blur: 1
        blurMultiplier: 0
        anchors.fill: icon
        blurEnabled: false
        Timer{
            interval: 5000
            running: true
            repeat: true
            onTriggered: {
                if (multiEffect.brightness)
                {
                    multiEffect.brightness = 0.00
                    interval = 5000

                }
                else
                {
                    multiEffect.brightness = 0.1
                    interval = 100
                }

            }
        }
    }
    */
}
