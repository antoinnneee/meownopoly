import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15


Rectangle {
    id: control
    color: "#333333"
    border.color: "#444444"
    border.width: 1
    property alias text: textSize.text
    property alias widthSpinBox: widthSpinBox

    signal valueChanged(var value)

    RowLayout {
        spacing: 4
        anchors.fill: parent
        anchors.leftMargin: 5
        anchors.rightMargin: 5
        anchors.topMargin: 1
        anchors.bottomMargin: 1

        
        Text {
            id: textSize
            text: "W:"
            color: "white"
            font.pixelSize: control.height * 0.7
            horizontalAlignment: Text.AlignLeft
            verticalAlignment: Text.AlignVCenter
            Layout.fillWidth: false
            Layout.preferredWidth: Screen.pixelDensity * 4
            Layout.fillHeight: true
        }
        SpinBox {
            id: widthSpinBox
            from: 1
            to: 200
            value: 4
            stepSize: 1
            editable: true
            Layout.fillHeight: true
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
            onValueChanged: {
                control.valueChanged(value)
            }
            background: Rectangle {
                color: "#2a2a2a"
                border.color: widthSpinBox.activeFocus ? "#0078d4" : "#555555"
                border.width: widthSpinBox.activeFocus ? 2 : 1
                radius: 3
            }
            
            contentItem: TextInput {
                text: widthSpinBox.displayText
                anchors.left: lessButton.right
                anchors.right: moreButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                font.pixelSize: control.height * 0.6
                color: "white"
                selectionColor: "#0078d4"
                selectedTextColor: "white"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                bottomPadding: 1
                readOnly: !widthSpinBox.editable
                validator: widthSpinBox.validator
                inputMethodHints: widthSpinBox.inputMethodHints
                anchors.leftMargin: 0
                anchors.rightMargin: 0
            }
            
            up.indicator: Rectangle {
                id: moreButton
                x: widthSpinBox.mirrored ? 0 : parent.width - width
                height: widthSpinBox.height
                implicitWidth: Screen.pixelDensity * 9
                color: widthSpinBox.up.pressed ? "#404040" : (widthSpinBox.up.hovered ? "#353535" : "#2a2a2a")
                border.color: widthSpinBox.activeFocus ? "#0078d4" : "#555555"
                border.width: widthSpinBox.activeFocus ? 2 : 1
                radius: 3
                
                Text {
                    text: "+"
                    anchors.fill: parent
                    font.pixelSize: parent.height * 0.55
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    bottomPadding: 2
                    color: widthSpinBox.up.pressed ? "#cccccc" : "white"
                }
            }
            
            down.indicator: Rectangle {
                id: lessButton
                x: widthSpinBox.mirrored ? parent.width - width : 0
                height: widthSpinBox.height
                implicitWidth: Screen.pixelDensity * 9
                color: widthSpinBox.down.pressed ? "#404040" : (widthSpinBox.down.hovered ? "#353535" : "#2a2a2a")
                border.color: widthSpinBox.activeFocus ? "#0078d4" : "#555555"
                border.width: widthSpinBox.activeFocus ? 2 : 1
                radius: 3
                
                Text {
                    text: "−"
                    anchors.fill: parent
                    font.pixelSize: parent.height * 0.55
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    bottomPadding: 2
                    color: widthSpinBox.down.pressed ? "#cccccc" : "white"
                }
            }
        }
    }

}

