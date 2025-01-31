import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Controls.Material.impl

ProgressBar {
    id: pbProgress
    height: 50
    value: 0.3
    width: 500
    indeterminate: true
    property color progressColor: AppStyle.globalPrimaryAccent
    property color backgroundColor: AppStyle.backgroundLight

    contentItem: ProgressBarImpl
    {
        implicitHeight: pbProgress.height
        anchors.fill: parent
        anchors.margins: 0
        scale: pbProgress.mirrored ? -1 : 1
        progress: pbProgress.position
        indeterminate: pbProgress.visible && pbProgress.indeterminate
        color: progressColor
    }

    background: Rectangle {
        anchors.fill: parent
        color: backgroundColor
    }
}
