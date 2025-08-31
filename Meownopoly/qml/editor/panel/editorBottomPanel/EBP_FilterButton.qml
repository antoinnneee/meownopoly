import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import "../"

RowLayout {
    id: filterButton
    visible: true
    spacing: 10

    required property string activeFilter
    property var buttonModel : ["Button 1", "Button 2", "Button 3"]

    signal buttonClicked(string text, int index)
    Repeater {
        model: buttonModel        
        Button {
            text: modelData
            flat: true
            checkable: true
            checked: filterButton.activeFilter === modelData
            width: 200
            required property int index
            required property var modelData
            
            background: Rectangle {
                color: parent.checked ? "#4A90E2" : "transparent"
                border.color: "#4A90E2"
                border.width: 1
                radius: 4
            }
            
            contentItem: Text {
                text: parent.text
                color: parent.checked ? "white" : "#4A90E2"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                filterButton.buttonClicked(text, index)
            }
        }
    }
}
