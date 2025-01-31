import QtQuick 2.12
import QtQuick.Controls 2.12

TextField{
    id:control

    width: 200
    height: 2*contentHeight
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    property alias controlText: control.text
    property alias backgroundColor: rectangle.color
    property bool largeSeparator: false
    selectByMouse: true
    cursorVisible: false
    mouseSelectionMode: TextInput.SelectWords
    font.pointSize: 10
    color: AppStyle.globalText


    MouseArea{
        id: ma
        anchors.fill: rectangle
        anchors.bottomMargin: -3
        anchors.leftMargin: 0
        anchors.topMargin: -7
        onClicked: control.focus = true
        onDoubleClicked: {

            control.focus = true
            control.selectAll()
        }
    }

    Rectangle {
        id: rectangle
        z:-1
        height: 2
        opacity: 0.7
        color: AppStyle.primary

        border.color: AppStyle.primary
        border.width: 1
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.rightMargin: (largeSeparator) ? 5 : parent.width/4
        anchors.verticalCenterOffset: control.font.pixelSize + 5
        anchors.leftMargin: (largeSeparator) ? 5 : parent.width/4
        radius: 1
    }
}



/*##^##
Designer {
    D{i:0;formeditorZoom:1.75;height:50;width:250}
}
##^##*/
