import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case

Rectangle {
    id: root
    height: 40
    color: "#007bff"
    radius: 4

    signal closeClicked()

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        
        Text {
            text: "Configuration de Case"
            color: "white"
            font.bold: true
            font.pixelSize: 16
            Layout.fillWidth: true
        }
        
        Button {
            text: "×"
            background: Rectangle {
                color: "transparent"
            }
            contentItem: Text {
                text: parent.text
                color: "white"
                font.bold: true
                font.pixelSize: 18
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            onClicked: {
                root.closeClicked()
            }
        }
    }
}