import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

Switch {
    id:control
    text: qsTr("Switch")
    states: [
        State {
            name: "State1"
            when: AppStyle.darkEnable

            PropertyChanges {
                target: text1
                color: control.down ? Qt.lighter(AppStyle.primary, 1.2) : AppStyle.primary
            }

            PropertyChanges {
                target: rectangle
                border.color: control.checked ? (control.down ? Qt.lighter(AppStyle.primary, 1.2) : Qt.lighter(AppStyle.primary, 1.1) ) : "#999999"
            }

            PropertyChanges {
                target: rectangle1
                border.color: control.checked ? (control.down ? Qt.lighter(AppStyle.primary, 1.2) : Qt.lighter(AppStyle.primary, 1.1) )  :  AppStyle.primary
            }
        }
    ]

    indicator: Rectangle {
        id: rectangle1
        implicitWidth: 48
        implicitHeight: 26
        x: control.leftPadding
        y: parent.height / 2 - height / 2
        radius: 13
        color: control.checked ? AppStyle.primary: AppStyle.backgroundButLight
        border.color: control.checked ? (control.down ? Qt.darker(AppStyle.primary, 1.2) : Qt.darker(AppStyle.primary, 1.1) )  :  AppStyle.primary

        Rectangle {
            id: rectangle
            x: control.checked ? parent.width - width : 0
            width: 26
            height: 26
            radius: 13
            color: control.down ? "#cccccc" : "#ffffff"
            border.color: control.checked ? (control.down ? Qt.darker(AppStyle.primary, 1.2) : Qt.darker(AppStyle.primary, 1.1) ) : "#999999"
        }
    }

    contentItem: Text {
        id: text1
        text: control.text
        font: control.font
        opacity: enabled ? 1.0 : 0.3
        color: control.down ? Qt.darker(AppStyle.primary, 1.2) : AppStyle.primary
        verticalAlignment: Text.AlignVCenter
        minimumPixelSize: 13
        minimumPointSize: 13
        leftPadding: control.indicator.width + control.spacing
    }
}
