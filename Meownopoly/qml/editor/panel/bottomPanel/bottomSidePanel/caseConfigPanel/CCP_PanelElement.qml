import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import theme

GroupBox {
    property var targetCase: null
    property bool updatingValues: false
    
    // Auto-size to content height
    Layout.fillWidth: true
    
    // Style pour le thème sombre
    label: Text {
        text: parent.title
        color: Theme.textSecondary
        font.bold: true
        font.pixelSize: Theme.fontSizeBody
    }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusS
        border.color: Theme.border
        border.width: 1
    }
}
