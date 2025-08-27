import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts

RowLayout {
    id: control
    property alias sliderText: sliderText.text
    property alias value: slider.value
    property alias from: slider.from
    property alias to: slider.to

    signal effectChanged(var value)

    Label {
        id: sliderText
        text: "Brightness :"
        verticalAlignment: Text.AlignVCenter
        color: "#cccccc"
        font.pointSize: 8
        Layout.preferredWidth: Screen.pixelDensity * 17
        Layout.fillHeight: true
    }

    // Slider
    Slider {
        id: slider
        Layout.fillWidth: true
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
        color: "#444444"
        scale: slider.horizontal && slider.mirrored ? -1 : 1

        Rectangle {
            y: slider.horizontal ? 0 : slider.visualPosition * parent.height
            width: slider.horizontal ? slider.position * parent.width : 6
            height: slider.horizontal ? 6 : slider.position * parent.height

            radius: 3
            color: "#569c58"
        }
    }
        
        handle: Rectangle {
            implicitWidth: 12
            implicitHeight: 12
            x: slider.leftPadding + (slider.horizontal ? slider.visualPosition * (slider.availableWidth - width) : (slider.availableWidth - width) / 2)
            y: slider.topPadding + (slider.horizontal ? (slider.availableHeight - height) / 2 : slider.visualPosition * (slider.availableHeight - height))
            radius: width / 2
            color: slider.pressed ? "#569c58" : "#444444"
            border.width: slider.visualFocus ? 2 : 1
            border.color: slider.pressed ? "#444444" : "#569c58"
        }
    }
    
    Text {
        text: slider.value.toFixed(2)
        color: "#cccccc"
        font.pixelSize: 10
        Layout.preferredWidth: 35
    }
    
    Button {
        text: "Reset"
        onClicked: slider.value = 0.0
        Layout.fillHeight: true
        width:  Screen.pixelDensity * 7
        
        background: Rectangle {
            color: parent.pressed ? "#666666" : "#555555"
            radius: 4
            anchors.fill: parent
        }
        
        contentItem: Text {
            text: parent.text
            color: "#cccccc"
            font.pointSize: 8
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
