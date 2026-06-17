import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import theme

Button {
    visible: true
    text: "← Back"
    flat: true

    background: Rectangle {
        color: parent.pressed ? Theme.borderLight : "transparent"
        border.color: Theme.textDisabled
        border.width: 1
        radius: Theme.radiusS
    }

    contentItem: Text {
        text: parent.text
        color: Theme.textPrimary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

}
