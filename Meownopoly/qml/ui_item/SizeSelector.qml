import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import theme


Rectangle {
    id: control
    color: Theme.surfaceAlt
    border.color: Theme.border
    border.width: 1
    property alias text: textSize.text
    property alias widthSpinBox: widthSpinBox

    signal valueChanged(var value)

    RowLayout {
        spacing: Theme.spacingXS
        anchors.fill: parent
        anchors.leftMargin: Theme.spacingXS
        anchors.rightMargin: Theme.spacingXS
        anchors.topMargin: 1
        anchors.bottomMargin: 1

        
        Text {
            id: textSize
            text: "W:"
            color: Theme.textPrimary
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
                color: Theme.surface
                border.color: widthSpinBox.activeFocus ? Theme.accent : Theme.borderLight
                border.width: widthSpinBox.activeFocus ? 2 : 1
                radius: Theme.radiusXS
            }
            
            contentItem: TextInput {
                text: widthSpinBox.displayText
                anchors.left: lessButton.right
                anchors.right: moreButton.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                font.pixelSize: control.height * 0.6
                color: Theme.textPrimary
                selectionColor: Theme.accent
                selectedTextColor: Theme.textPrimary
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
                color: widthSpinBox.up.pressed ? Theme.border : (widthSpinBox.up.hovered ? Theme.surfaceHover : Theme.surface)
                border.color: widthSpinBox.activeFocus ? Theme.accent : Theme.borderLight
                border.width: widthSpinBox.activeFocus ? 2 : 1
                radius: Theme.radiusXS
                
                Text {
                    text: "+"
                    anchors.fill: parent
                    font.pixelSize: parent.height * 0.55
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    bottomPadding: 2
                    color: widthSpinBox.up.pressed ? Theme.textSecondary : Theme.textPrimary
                }
            }
            
            down.indicator: Rectangle {
                id: lessButton
                x: widthSpinBox.mirrored ? parent.width - width : 0
                height: widthSpinBox.height
                implicitWidth: Screen.pixelDensity * 9
                color: widthSpinBox.down.pressed ? Theme.border : (widthSpinBox.down.hovered ? Theme.surfaceHover : Theme.surface)
                border.color: widthSpinBox.activeFocus ? Theme.accent : Theme.borderLight
                border.width: widthSpinBox.activeFocus ? 2 : 1
                radius: Theme.radiusXS
                
                Text {
                    text: "−"
                    anchors.fill: parent
                    font.pixelSize: parent.height * 0.55
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    bottomPadding: 2
                    color: widthSpinBox.down.pressed ? Theme.textSecondary : Theme.textPrimary
                }
            }
        }
    }

}

