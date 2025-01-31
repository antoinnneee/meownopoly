import QtQuick 2.12
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15
import "."

ToolButton {
    id: control
    text: qsTr("ToolButton")
    checkable: true
    width: 120
    property int buttonIndex: 0

    font.bold: control.checked || control.down
    font.pointSize: 10
    /*
    onCheckedChanged: {
        if (!checked)
        {
            animOutR.start()
        }
        else
        {
            animInR.start()
        }
    }
*/

    contentItem: Text {
        text: control.text
        font: control.font
        opacity: enabled ? 1.0 : 0.3
        color: (control.checked)?AppStyle.globalText:  AppStyle.primary
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        z:1

    }


    background: Rectangle {
        id:bg
        implicitWidth: 40

        color: (control.enabled && (control.checked || control.highlighted))? AppStyle.globalPrimaryAccent : "#00ffffff"
        implicitHeight: 40
        //border.color: Qt.lighter(AppStyle.primary, control.enabled && (control.checked || control.highlighted) ? 1.2 : 1.1)
        opacity: enabled ? 1 : 0.3
        border.color:  Qt.lighter(AppStyle.primary, control.enabled && (control.checked || control.highlighted) ? ((control.hovered)? 1.4 : 1) : ((control.hovered)? 1.4 : 1.6))
        Behavior on border.color { ColorAnimation { duration : 200 } }

        visible: true
    }
}

/*##^##
Designer {
    D{i:0;formeditorZoom:1.33}
}
##^##*/
