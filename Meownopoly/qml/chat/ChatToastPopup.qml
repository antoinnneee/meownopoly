import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import theme

Popup {
    id: root
    width: 280
    x: parent ? parent.width - width - 16 : 0
    y: 60
    padding: 0
    modal: false
    dim: false
    closePolicy: Popup.NoAutoClose

    ListModel {
        id: toastStackModel
    }

    function show(senderName, text) {
        toastStackModel.insert(0, {
            sender: senderName,
            text: text,
            expiresAt: Date.now() + 4000
        })
        open()
    }

    background: Rectangle {
        color: "transparent"
        border.width: 0
    }

    contentItem: Column {
        id: toastColumn
        width: root.width
        spacing: Theme.spacingM
        Repeater {
            model: toastStackModel
            delegate: Rectangle {
                width: toastColumn.width - 16
                x: 8
                color: "#E6333333"
                border.color: Theme.accent
                border.width: 1
                radius: Theme.radiusL
                height: contentColToast.height + 24

                Column {
                    id: contentColToast
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.spacingXL
                    spacing: Theme.spacingS
                    width: parent.width - 24
                    Text {
                        text: "💬 " + model.sender
                        color: Theme.accent
                        font.pixelSize: Theme.fontSizeSmall
                        font.bold: true
                        width: parent.width - 24
                        elide: Text.ElideRight
                    }
                    Text {
                        text: model.text
                        color: Theme.textSecondary
                        font.pixelSize: Theme.fontSizeBody
                        width: parent.width - 24
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }

    Timer {
        id: toastPruneTimer
        interval: 500
        repeat: true
        running: toastStackModel.count > 0
        onTriggered: {
            var now = Date.now()
            for (var i = toastStackModel.count - 1; i >= 0; i--) {
                if (toastStackModel.get(i).expiresAt < now) {
                    toastStackModel.remove(i)
                }
            }
            if (toastStackModel.count === 0)
                root.close()
        }
    }
}
