import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs
import theme


Rectangle {
    id: mirrorButton
    required property bool isHorizontal
    required property bool isMirrored
    
    color: isMirrored ? Theme.hover(Theme.surfaceHover) : Theme.surfaceHover
    border.color: Theme.textDisabled
    border.width: 1
    radius: Theme.radiusS

    signal clicked()
    
    Text {
        anchors.centerIn: parent
        text: mirrorButton.isHorizontal ? "↔️" : "↕️"
        font.pixelSize: Theme.fontSizeLarge
    }
    
    MouseArea {
        id: mirrorMouseArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: mirrorButton.opacity = 0.8
        onExited: mirrorButton.opacity = 1.0
        onClicked: mirrorButton.clicked()
    }


}
