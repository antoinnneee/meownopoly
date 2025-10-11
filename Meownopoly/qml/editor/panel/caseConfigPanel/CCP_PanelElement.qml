import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

GroupBox {
    property var targetCase: null
    property bool updatingValues: false
    
    // Auto-size to content height
    Layout.fillWidth: true
    
    // Style pour le thème sombre
    label: Text {
        text: parent.title
        color: "#cccccc"
        font.bold: true
        font.pixelSize: 12
    }
    
    background: Rectangle {
        color: "#2a2a2a"
        radius: 4
        border.color: "#444444"
        border.width: 1
    }
}
