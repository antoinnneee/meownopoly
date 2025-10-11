import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs


Rectangle {
    id: mirrorButton
    required property bool isHorizontal
    required property bool isMirrored
    
    color: isMirrored ? "#4e4e4e" : "#3a3a3a"
    border.color: "#666666"
    border.width: 1
    radius: 4

    signal clicked()
    
    Text {
        anchors.centerIn: parent
        text: mirrorButton.isHorizontal ? "↔️" : "↕️"
        font.pixelSize: 16
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
