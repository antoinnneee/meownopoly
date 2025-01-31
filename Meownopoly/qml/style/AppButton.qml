import QtQuick 2.15
import QtQuick.Controls 2.15

AbstractButton {
    id: control
    text: qsTr("Button")
    antialiasing: true


    states: [
        State {
            name: "dark"
            when: AppStyle.darkEnable
            PropertyChanges {
                target: text1
                color: AppStyle.textLight
            }

            PropertyChanges {
                target: rectangle
                color: (checked) ? Qt.lighter(AppStyle.backgroundButDark, 1.4) :(!control.down) ? AppStyle.backgroundButDark : Qt.lighter(AppStyle.backgroundButDark, 1.3)
                border.color: (checked) ? Qt.lighter(AppStyle.primary, 1.2) : AppStyle.primary
            }
        }
    ]
    font.pointSize: 10

    contentItem: Text {
        id: text1
        text: control.text
        font: control.font
        opacity: control.enabled ? 1.0 : 0.3
        color: AppStyle.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }

    background: Rectangle {
        id: rectangle
        implicitWidth: 100
        implicitHeight: 40
        opacity: control.enabled ? 1 : 0.3
        color: (checked) ? Qt.darker(AppStyle.backgroundButLight, 1.2) : (!control.down) ? AppStyle.backgroundButLight : Qt.darker(AppStyle.backgroundButLight, 1.1)

        border.color: AppStyle.primary
        border.width: 1
        radius: 1
    }
}

/*##^##
Designer {
    D{i:0;height:40;width:100}
}
##^##*/
