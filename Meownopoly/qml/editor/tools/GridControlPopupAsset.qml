import QtQuick 2.15
import QtQuick.Controls

import Game

Popup {
    id: selectDecorationPopup
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
    onOpened: {
        Game.checkDecorationAssets()
        openSelectPopup.running = true
    }
    onClosed: closeSelectPopup.running = true


    Text {
        id: selectDecorationTitle
        text: "Select Decoration Asset"
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        font.bold: true
        font.pixelSize: 16
        padding: 10
    }

    ScrollView {
        anchors.fill: parent
        anchors.topMargin: selectDecorationTitle.height + 5
        GridView {
            model: Game.assetNumber
            clip: true
            delegate: Image {
                required property int index
                source: Game.getAssetPath(index)
                width: 100
                height: 100
                Text {
                    id: checked
                    anchors.fill: parent
                    text : "✓"
                    color: "green"
                    font.pixelSize: 20
                    opacity: 0
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        console.log("Clicked on asset index:", index)
                        checked.opacity = !checked.opacity
                    }
                }
            }
        }
    }


    Button {
        text: "Select"
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        onClicked: {
            console.log("Selected assets")
            selectDecorationPopup.close()
        }
    }

    NumberAnimation {
        id: openSelectPopup
        target: selectDecorationPopup
        property: "opacity"
        duration: 200
        easing.type: Easing.OutCubic
        from: 0
        to: 1
    }
    NumberAnimation {
        id: closeSelectPopup
        target: selectDecorationPopup
        property: "opacity"
        duration: 200
        easing.type: Easing.OutCubic
        from: 0
        to: 1
    }
}
