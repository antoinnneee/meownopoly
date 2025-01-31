import QtQuick 2.12
import QtQuick.Controls 2.15
import "."

ToolSeparator {
    id: control

    contentItem: Rectangle {
        implicitWidth: parent.vertical ? 1 : 24
        implicitHeight: parent.vertical ? 24 : 1
        color: AppStyle.globalPrimaryAccent
    }
}

/*##^##
Designer {
    D{i:0;autoSize:true;height:480;width:640}
}
##^##*/
