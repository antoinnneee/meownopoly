import QtQuick 2.12
import QtQuick.Controls 2.12
import "."

CheckBox {
    id: checkbox
    text: qsTr("CheckBox")
    states: [
        State {
            name: "dark"
            when: AppStyle.darkEnable

            PropertyChanges {
                target: extIndicator
                //                color: checkbox.down ? Qt.lighter(AppStyle.primary, 1.1) : AppStyle.primary
                color: "#00ffffff"
                border.color: Qt.lighter(AppStyle.primary, (checkbox.hovered)? 1.15 : 1)

            }
            PropertyChanges {
                target: intIndicator
                //                color: "#ffffff"
            }
            PropertyChanges {
                target: textLabel
                color: AppStyle.textLight
            }
        }
    ]
    font.pointSize: 9
    checked: false

    indicator: Rectangle {
        id:extIndicator
        implicitWidth: 26
        implicitHeight: 26
        x: checkbox.leftPadding
        y: parent.height / 2 - height / 2
        radius: 3
        border.color: Qt.darker(AppStyle.primary, (checkbox.hovered)? 1.15 : 1)
        Behavior on border.color { ColorAnimation {duration : 200}}
        color: "#ffffff"
        Rectangle {
            id:intIndicator
            width: (checked) ? 14 : 0
            height: (checked) ? 14 : 0
            x: 6
            y: 6
            radius: 2
            anchors.centerIn: extIndicator
            opacity: visible
            color: checkbox.down ? Qt.darker(AppStyle.primary, 1.1) : AppStyle.primary
            Behavior on opacity { NumberAnimation {duration : 50}}
            Behavior on width {NumberAnimation { easing.amplitude: 0.1; easing.type: Easing.InOutQuad;duration : 200}}
            Behavior on height {NumberAnimation { easing.amplitude: 0.1; easing.type: Easing.InOutQuad;duration : 200}}
        }
    }

    contentItem: Text {
        id: textLabel
        text: checkbox.text
        font: checkbox.font
        opacity: enabled ? 1.0 : 0.3
        color: AppStyle.textDark
        verticalAlignment: Text.AlignVCenter
        leftPadding: checkbox.indicator.width + checkbox.spacing
    }
}


