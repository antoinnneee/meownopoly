import QtQuick
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

GroupBox {
    id: control

    title: "Transform"
    
    // Properties for the target decoration element
    property alias rotationSlider: rotationSection.rotationSlider
    property alias horizontalMirrorCheck: horizontalMirrorCheck
    property alias verticalMirrorCheck: verticalMirrorCheck
    property bool isCollapsed: false
    // Dimensions
    height: (isCollapsed ? Screen.pixelDensity * 12 : mainLayout.implicitHeight +  Screen.pixelDensity * 12)
    width: mainLayout.implicitWidth

    // Signals
    signal effectChanged()

    padding: 4
    spacing: 2

    background: Rectangle {
        color: "#2a2a2a"
        radius: 8
        border.color: "#444444"
        border.width: 1
    }

    label: RowLayout {
        id : titleLabel
        x: control.leftPadding
        width: control.availableWidth
        spacing: 8

        Text {
            text: control.title
            color: "#ffffff"
            font.pixelSize: 16
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
        }

        Button {
            id: collapseButton
            Layout.preferredWidth: Screen.pixelDensity * 8
            Layout.preferredHeight: Screen.pixelDensity * 8
            flat: true

            background: Rectangle {
                color: "transparent"
                border.color: "#666666"
                border.width: 1
                radius: 2
            }

            contentItem: Text {
                text: control.isCollapsed ? "▼" : "▲"
                color: "#cccccc"
                font.pixelSize: 10
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            onClicked: {
                control.isCollapsed = !control.isCollapsed
            }
        }
    }

    // Main layout
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.topMargin: -4
        spacing: 10
        visible: !control.isCollapsed
        VEP_Rotation{
            id: rotationSection
            Layout.fillWidth: true
            onEffectChanged: {
                control.effectChanged()
            }
        }
    }
        
        // Hidden checkboxes for mirror functionality (kept for compatibility)
        CheckBox {
            id: horizontalMirrorCheck
            visible: false
            checked: false
            
            onCheckedChanged: {
                control.effectChanged()
            }
        }
        
        CheckBox {
            id: verticalMirrorCheck
            visible: false
            checked: false
            
            onCheckedChanged: {
                control.effectChanged()
            }
        }


    function updateFromDisplayParameter(dispParam) {
      rotationSection.rotationSlider.value = dispParam.rotationAngle

      // Update mirror checkboxes
      horizontalMirrorCheck.checked = dispParam.mirrorHorizontal
      verticalMirrorCheck.checked = dispParam.mirrorVertical
    }


}
