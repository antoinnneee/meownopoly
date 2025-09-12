import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Effects
import QtQuick.Dialogs

import QtQuick.Controls.impl

GroupBox {
    id: control
    title: "Advanced Effects"
    
    property alias blurSlider: blurSlider
    property alias blurEnabledCheck: blurEnabledCheck
    property alias shadowBlurSlider: shadowBlurSlider
    property alias shadowEnabledCheck: shadowEnabledCheck

    property bool isCollapsed: false
    height: (isCollapsed ? Screen.pixelDensity * 9 : mainLayout.implicitHeight)

    signal effectChanged()

    padding:4
    spacing: 2

    background: Rectangle {
        color: "#333333"
        radius: 4
        border.color: "#555555"
        border.width: 1
    }
    label: RowLayout {
        x: control.leftPadding
        width: control.availableWidth
        spacing: 8
        
        Text {
            color: "#cccccc"
            text: control.title
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
    
    ColumnLayout {
        id: mainLayout
        anchors.fill: parent
        anchors.topMargin: -4
        spacing: 1
        visible: !control.isCollapsed
        
        // Blur effect
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            
            CheckBox {
                id: blurEnabledCheck
                Layout.fillHeight: true

                onCheckedChanged: {
                        control.effectChanged()
                }
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20

                    x: blurEnabledCheck.text ? (blurEnabledCheck.mirrored ? blurEnabledCheck.width - width - blurEnabledCheck.rightPadding : blurEnabledCheck.leftPadding) : blurEnabledCheck.leftPadding + (blurEnabledCheck.availableWidth - width) / 2
                    y: blurEnabledCheck.topPadding + (blurEnabledCheck.availableHeight - height) / 2
                    color: blurEnabledCheck.checked ? "#4CAF50" : "#444444"
                    border.width: blurEnabledCheck.visualFocus ? 2 : 1
                    border.color:  "#666666" 
                    radius: 3

                    ColorImage {
                        x: (parent.width - width) / 2
                        y: (parent.height - height) / 2
                        defaultColor: "#cfd0d1"
                        color: blurEnabledCheck.palette.text
                        source: "qrc:/qt-project.org/imports/QtQuick/Controls/Basic/images/check.png"
                        visible: blurEnabledCheck.checkState === Qt.Checked
                    }
                }
                
            }
            
            VEP_Slider {
                id: blurSlider
                Layout.fillWidth: true
                Layout.fillHeight: true
                sliderText: "Blur:"
                from: 0
                to: 1
                onEffectChanged: function(value) {
                        control.effectChanged()
                }
            }

        }
        
        // Shadow effect
        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            
            CheckBox {
                id: shadowEnabledCheck

                Layout.fillHeight: true
                indicator: Rectangle {
                    implicitWidth: 20
                    implicitHeight: 20

                    x: shadowEnabledCheck.text ? (shadowEnabledCheck.mirrored ? shadowEnabledCheck.width - width - shadowEnabledCheck.rightPadding : shadowEnabledCheck.leftPadding) : shadowEnabledCheck.leftPadding + (shadowEnabledCheck.availableWidth - width) / 2
                    y: shadowEnabledCheck.topPadding + (shadowEnabledCheck.availableHeight - height) / 2
                    color: shadowEnabledCheck.checked ? "#4CAF50" : "#444444"
                    border.width: shadowEnabledCheck.visualFocus ? 2 : 1
                    border.color:  "#666666" 
                    radius: 3

                    ColorImage {
                        x: (parent.width - width) / 2
                        y: (parent.height - height) / 2
                        defaultColor: "#cfd0d1"
                        color: shadowEnabledCheck.palette.text
                        source: "qrc:/qt-project.org/imports/QtQuick/Controls/Basic/images/check.png"
                        visible: shadowEnabledCheck.checkState === Qt.Checked
                    }
                }

                
                onCheckedChanged: {
                    control.effectChanged()
                }

            }
            
            VEP_Slider {
                id: shadowBlurSlider
                Layout.fillHeight: true
                Layout.fillWidth: true
                sliderText: "Shadow Blur:"
                from: 0
                to: 1
                onEffectChanged: function(value) {
                        control.effectChanged()
                }
            }
        }
    }
}
