import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "titleScreen/"
import QtQuick.Window

import Qt.labs.platform

ApplicationWindow {
    id: root
    width: 640
    height: 480
    visible: true
    StackView {
        anchors.fill: parent
        initialItem: titleScreen
    }

    Component{
        id: titleScreen
        TitleScreen{}
    }
}
