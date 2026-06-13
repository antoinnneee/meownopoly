import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import theme


GroupBox {
    id: control
    title: "Box Title"
    property bool isCollapsed: false
    property alias titleLabel: titleLabel
    font.pixelSize: Theme.fontSizeLarge
    clip: true


    width:200
    height: control.titleLabel.height + control.spacing + control.topPadding  + ((!control.isCollapsed ? mainLayout.implicitHeight  + control.bottomPadding : 0))
    implicitHeight: control.titleLabel.height + control.spacing +  control.topPadding  + ((!control.isCollapsed ? mainLayout.implicitHeight + control.bottomPadding : 0))

    property alias content : mainLayout.children

    topPadding: Theme.spacingXXS
    bottomPadding: Theme.spacingXXS
    spacing: Theme.spacingXXS

    background: Rectangle {
        color: Theme.surfaceAlt
        radius: Theme.radiusS
        border.color: Theme.borderLight
        border.width: 1

    }

    label: MouseArea {
        id: titleLabel
        x: control.leftPadding
        width: control.availableWidth
        height: control.font.pixelSize + Theme.spacingXS

        onClicked: {
            control.isCollapsed = !control.isCollapsed
        }
        RowLayout {
            spacing: Theme.spacingM
            anchors.fill: parent

            Text {
                color: Theme.textSecondary
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
