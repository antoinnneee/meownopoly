import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme


Button {
    text: "✕ Clear"
    flat: true

    background: Rectangle {
        color: parent.pressed ? Theme.pressed(Theme.dangerSoft) : "transparent"
        border.color: Theme.dangerSoft
        border.width: 1
        radius: Theme.radiusS
    }

    contentItem: Text {
        text: parent.text
        color: Theme.dangerSoft
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        font.pixelSize: Theme.fontSizeSmall
    }

    onClicked: {
        // Signal to parent to clear selection
        titleBar.caseSelected("", "")
    }
}
