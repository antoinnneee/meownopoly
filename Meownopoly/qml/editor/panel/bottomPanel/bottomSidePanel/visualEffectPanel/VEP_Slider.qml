import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import theme

RowLayout {
    id: control
    property alias sliderText: sliderText.text
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to

    property color accentColor: Theme.accentAlt
    signal effectChanged(var value)


    clip: true

    Label {
        id: sliderText
        text: "Brightness :"
        verticalAlignment: Text.AlignVCenter
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeSmall
        Layout.preferredWidth: Screen.pixelDensity * 17
        Layout.minimumWidth: Screen.pixelDensity * 13
        Layout.fillHeight: true
    }

    // Slider
    Slider {
        id: slider
        Layout.fillWidth: true
        Layout.minimumWidth: Screen.pixelDensity * 17
        Layout.fillHeight: true
        from: -1.0
        to: 1.0
        value: 0.0
        stepSize: 0.01

        onValueChanged: {
                control.effectChanged(value)
        }

        background: Rectangle {
        x: slider.leftPadding + (slider.horizontal ? 0 : (slider.availableWidth - width) / 2)
        y: slider.topPadding + (slider.horizontal ? (slider.availableHeight - height) / 2 : 0)
        implicitWidth: slider.horizontal ? 200 : 6
        implicitHeight: slider.horizontal ? 6 : 200
        width: slider.horizontal ? slider.availableWidth : implicitWidth
        height: slider.horizontal ? implicitHeight : slider.availableHeight
        radius: 3
        color: Theme.border
        scale: slider.horizontal && slider.mirrored ? -1 : 1

        Rectangle {
            y: slider.horizontal ? 0 : slider.visualPosition * parent.height
            width: slider.horizontal ? slider.position * parent.width : 6
            height: slider.horizontal ? 6 : slider.position * parent.height

            radius: 3
            color: control.accentColor
        }
    }
        
        handle: Rectangle {
            implicitWidth: Screen.pixelDensity*3
            implicitHeight: Screen.pixelDensity*6
            x: slider.leftPadding + (slider.horizontal ? slider.visualPosition * (slider.availableWidth - width) : (slider.availableWidth - width) / 2)
            y: slider.topPadding + (slider.horizontal ? (slider.availableHeight - height) / 2 : slider.visualPosition * (slider.availableHeight - height))
            radius: width / 2
            color: slider.pressed ? control.accentColor : Theme.border
            border.width: slider.visualFocus ? 2 : 1
            border.color: slider.pressed ? Theme.border : control.accentColor
        }
    }
    
    Text {
        text: slider.value.toFixed(2)
        color: Theme.textSecondary
        font.pixelSize: Theme.fontSizeCaption
        Layout.preferredWidth: 35
    }
    
    Button {
        text: "Reset"
        onClicked: slider.value = 0.0
        // Layout.fillHeight: true
        Layout.minimumWidth: Screen.pixelDensity * 7
        Layout.preferredWidth: Screen.pixelDensity * 14
        Layout.preferredHeight: Screen.pixelDensity * 8
        
        background: Rectangle {
            color: parent.pressed ? Theme.hover(Theme.borderLight) : Theme.borderLight
            radius: Theme.radiusS
            anchors.fill: parent
        }

        contentItem: Text {
            anchors.fill:parent
            text: parent.text
            color: Theme.textSecondary
            font.pixelSize: Theme.fontSizeSmall
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
