import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

GroupBox {
    property var targetCase: null
    
    // Auto-size to content height
    Layout.fillWidth: true
//    implicitHeight: contentItem ? contentItem.implicitHeight + topPadding + bottomPadding : 0
}
