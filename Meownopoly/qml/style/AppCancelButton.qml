import QtQuick 2.15
import QtQuick.Controls 2.15
import "."

Button {
    id: control
    text: qsTr("Button")
    antialiasing: true

    states: [
        State {
            name: "dark"
            when: AppStyle.darkEnable

            PropertyChanges {
                target: rectangle
                color: (!control.down) ? AppStyle.cancelDark : Qt.darker(AppStyle.cancelDark,1.3)
                border.color: Qt.darker(AppStyle.cancelDark,1.1)
            }
        }
    ]
    font.pointSize: 10
    font.bold: true

    contentItem: Text {
        id: text1
        text: control.text
        font: control.font
        opacity: control.enabled ? 1.0 : 0.3
        color: AppStyle.textLight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        id: rectangle
        implicitWidth: 100
        implicitHeight: 40
        opacity: control.enabled ? 1 : 0.3
        color: (!control.down) ? AppStyle.cancel : Qt.lighter(AppStyle.cancel, 1.1)

        border.color: Qt.darker(AppStyle.cancel,1.1)
        border.width: 1
        radius: 1
    }
}


