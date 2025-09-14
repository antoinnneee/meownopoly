import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../item_icon"
import ".."

Item {
    id: root    
    required property EditorLogic logic
    property bool isExpanded: false

    // Signal émis quand un bouton est cliqué

    enum ButtonType {
        Assets,
        Cases,
        Edition
    }
    
    signal buttonClicked(int index)

    // Boutons de menu
    RowLayout {
        id: menuSelector
        anchors.left: parent.left
        height: parent.height
        spacing: 0

        Button {
            id: expandButton
            width: 30
            Layout.fillHeight: true
            background: Rectangle {
                anchors.fill: parent
                color: parent.pressed ? "#555555" : "#444444"
                border.color: "#666666"
                border.width: 1
                radius: 4
            }

            contentItem: Text {
                text: root.isExpanded ? "▼" : "▲"
                color: "white"
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                anchors.fill:expandButton
            }

            onClicked: {
                console.log("Expand button clicked");
                isExpanded = !isExpanded;
            }
        }

        ListModel {
            id: menuSelectorModel
            ListElement {
                menuText: "Menu Assets"
                menuColor: "#b05758"
                menuBorderColor: "#862a2a"
            }
            ListElement {
                menuText: "Menu Cases"
                menuColor: "#b3ab48"
                menuBorderColor: "#8a8224"
            }
            ListElement {
                menuText: "Menu Carte"
                menuColor: "#4a90e2"
                menuBorderColor: "#306aa8"
            }
        }

        Repeater {
            model: menuSelectorModel
            MenuSelector_Button {
                required property int index
                required property color menuColor
                required property string menuBorderColor
                required property string menuText
                Layout.fillHeight: true
                Layout.leftMargin: (index) ? -8 : 0
                z: -index
                buttonIndex: index
                mainColor: menuColor
                borderColor: menuBorderColor
                text: menuText
                onButtonClicked: function(index) {
                    root.buttonClicked(index)

                }
            }
        }
        ColumnLayout
        {
            height: parent.height
            width: Screen.pixelDensity * 35
            spacing: 0
            Layout.fillHeight: true
            SizeSelector{
                text: "W:"
                // @disable-check M16
                topLeftRadius: 3
                // @disable-check M16
                topRightRadius: 3
                Layout.fillHeight: true
                Layout.fillWidth: true
                widthSpinBox.value: logic.tileLogic.currentElementWidth
                onValueChanged: function(value) { logic.tileLogic.currentElementWidth = value }
            }
            SizeSelector{
                text: "H:"
                // @disable-check M16
                bottomLeftRadius: 3
                // @disable-check M16
                bottomRightRadius: 3
                Layout.fillHeight: true
                Layout.fillWidth: true
                widthSpinBox.value: logic.tileLogic.currentElementHeight
                onValueChanged: function(value) { logic.tileLogic.currentElementHeight = value }
            }
        }
    }
    
    // Contrôles de dimensions et outil curseur
    Rectangle {
        id: controlsBackground
        anchors.left: menuSelector.right
        anchors.leftMargin: 15
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height
        width: controlsRow.width + 20
        color: "#333333"
        radius: 4
        border.color: "#444444"
        border.width: 1
        
        Row {
            id: controlsRow
            anchors.centerIn: parent
            spacing: 10
            height: parent.height

            // Mouse cursor button
            Rectangle {
                id: cursorButton
                property bool checked: false
                
                width: 32
                height: 32
                radius: 4
                color: checked ? "#4A90E2" : "#444444"
                border.color: "#666666"
                border.width: 1
                anchors.verticalCenter: parent.verticalCenter
                
                Text {
                    text: "🖱️"
                    color: "white"
                    font.pixelSize: 14
                    anchors.centerIn: parent
                }
                
                MouseArea {
                    id: cursorMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    onPressed: {
                        checked = !checked
                        if (checked)
                            root.buttonClicked(root.BTN_EDITION)
                    }
                }
                
                ToolTip {
                    visible: cursorMouseArea.containsMouse
                    text: "Select cursor tool"
                    delay: 500
                }
            }
        }
    }
}
