import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import theme

RowLayout {
    id: filterButton
    visible: true
    spacing: Theme.spacingL

    required property string activeFilter
    onActiveFilterChanged: {
    }

    property var buttonModel : ["Button 1", "Button 2", "Button 3"]

    signal buttonClicked(string text, int index)
    Repeater {
        model: buttonModel        
        Button {
            id: button
            text: modelData
            flat: true
            checkable: true
            checked: filterButton.activeFilter === modelData
            width: 200
            required property int index
            required property var modelData

            background: Rectangle {
                color: parent.checked ? Theme.accent : "transparent"
                border.color: Theme.accent
                border.width: 1
                radius: Theme.radiusS
            }

            contentItem: Text {
                text: parent.text
                color: parent.checked ? Theme.textPrimary : Theme.accent
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            
            onClicked: {
                filterButton.buttonClicked(text, index)
                button.checked = Qt.binding(function() { return filterButton.activeFilter === button.modelData })

            }
        }
    }
}
