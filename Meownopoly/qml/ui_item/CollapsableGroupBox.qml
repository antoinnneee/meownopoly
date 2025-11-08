import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs


GroupBox {
    id: control
    title: "Box Title"
    property bool isCollapsed: false
    property alias titleLabel: titleLabel
    font.pointSize: 12


    width:200
    height: control.titleLabel.height + control.spacing + control.topPadding  + ((!control.isCollapsed ? mainLayout.implicitHeight  + control.bottomPadding : 0))
    implicitHeight: control.titleLabel.height + control.spacing +  control.topPadding  + ((!control.isCollapsed ? mainLayout.implicitHeight + control.bottomPadding : 0))

    property alias content : mainLayout.children

    topPadding: 2
    bottomPadding: 2
    spacing: 2

    background: Rectangle {
        color: "#333333"
        radius: 4
        border.color: "#555555"
        border.width: 1
    }

    label: MouseArea {
        id: titleLabel
        x: control.leftPadding
        width: control.availableWidth
        height: control.font.pixelSize + 4

        onClicked: {
            control.isCollapsed = !control.isCollapsed
        }
        RowLayout {
            spacing: 8
            anchors.fill: parent

            Text {
                color: "#cccccc"
                text: control.title
                font: control.font

                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        anchors.topMargin: titleLabel.height
        spacing: 1
        visible: !control.isCollapsed
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

}
