import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs


Rectangle {
    id: lockButton
    required property var effectsLocked
    color: effectsLocked ? "#4a4a4a" : "#3a3a3a"
    border.color: "#666666"
    border.width: 1
    radius: 4

    signal clicked()
    
    Text {
        anchors.centerIn: parent
        text: lockButton.effectsLocked ? "🔒" : "🔓"
        font.pixelSize: 16
    }
    
    MouseArea {
        id: lockMouseArea
        anchors.fill: parent
        hoverEnabled: true
        onEntered: lockButton.opacity = 0.8
        onExited: lockButton.opacity = 1.0
        onClicked: lockButton.clicked()
    }


}
