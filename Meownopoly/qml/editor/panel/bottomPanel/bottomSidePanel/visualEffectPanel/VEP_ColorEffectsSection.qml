import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import ui_item

CollapsableGroupBox {
    id: control
    title: "Color Effects"

    property alias brightnessSlider: brightnessSlider
    property alias contrastSlider: contrastSlider
    property alias saturationSlider: saturationSlider
    property alias colorizationSlider: colorizationSlider

    property color pickedColor: "#ffffff"
    property var colorPresets: []
    property int activePresetIndex: -1

    signal effectChanged()

    Settings {
        id: colorPresetSettings
        category: "Editor/ColorPresets"
        property string presetsData: ""
        property string lastColor: "#ffffff"
    }

    Component.onCompleted: {
        if (!loadColorPresets()) {
            colorPresets = [
                { color: "#ff0000" },
                { color: "#ffaa00" },
                { color: "#ffff00" },
                { color: "#00ff00" },
                { color: "#00ffff" },
                { color: "#0066ff" },
                { color: "#aa00ff" },
                { color: "#ff00aa" }
            ]
            saveColorPresets()
        }
        if (colorPresetSettings.lastColor)
            pickedColor = colorPresetSettings.lastColor
        _syncActiveIndex()
    }

    content : [

        VEP_Slider {
            id: brightnessSlider
            Layout.topMargin: 0
            Layout.fillWidth: true
            sliderText: "Brightness:"
            onEffectChanged: function(value) { control.effectChanged() }
        },

        VEP_Slider {
            id: contrastSlider
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Contrast:"
            onEffectChanged: function(value) { control.effectChanged() }
        },

        VEP_Slider {
            id: saturationSlider
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Saturation:"
            onEffectChanged: function(value) { control.effectChanged() }
        },

        VEP_Slider {
            id: colorizationSlider
            accentColor: control.pickedColor
            from: 0
            to: 1
            Layout.topMargin: 1
            Layout.fillWidth: true
            sliderText: "Colorization:"
            onEffectChanged: function(value) { control.effectChanged() }
        },

        GroupBox {
            title: "Colorization Color"
            Layout.fillWidth: true
            Layout.topMargin: 8

            background: Rectangle {
                color: "#2a2a2a"
                radius: 3
                border.color: "#444444"
                border.width: 1
                opacity: 0.1
            }

            label: Text {
                text: parent.title
                color: "#cccccc"
                font.pixelSize: 10
                font.bold: true
                x: 4
            }

            ColumnLayout {
                anchors.fill: parent
                spacing: 6

                VEP_InlineColorPicker {
                    id: picker
                    Layout.fillWidth: true
                    pickedColor: control.pickedColor
                    onColorEdited: function(c) {
                        control.pickedColor = c
                        colorPresetSettings.lastColor = c.toString()
                        control._syncActiveIndex()
                        control.effectChanged()
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 6

                    Text {
                        text: "Saved swatches"
                        color: "#cccccc"
                        font.pixelSize: 9
                    }

                    Item { Layout.fillWidth: true }

                    Text {
                        text: colorPresets.length + " / right-click to remove"
                        color: "#888888"
                        font.pixelSize: 9
                    }

                    Button {
                        text: "+"
                        ToolTip.visible: hovered
                        ToolTip.text: "Save current color"
                        implicitWidth: 26; implicitHeight: 22
                        onClicked: addPresetFromPicker()
                        background: Rectangle {
                            color: parent.pressed ? "#569c58" : "#4a8a4a"
                            radius: 3
                        }
                        contentItem: Text {
                            text: parent.text
                            color: "#ffffff"
                            font.pixelSize: 14; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }

                    Button {
                        text: "\u00D7"
                        ToolTip.visible: hovered
                        ToolTip.text: "Remove selected swatch"
                        enabled: activePresetIndex >= 0
                        implicitWidth: 26; implicitHeight: 22
                        onClicked: removePreset(activePresetIndex)
                        background: Rectangle {
                            color: parent.enabled ? (parent.pressed ? "#cc4444" : "#aa4444") : "#444444"
                            radius: 3
                        }
                        contentItem: Text {
                            text: parent.text
                            color: parent.enabled ? "#ffffff" : "#888888"
                            font.pixelSize: 14; font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 4

                    Repeater {
                        model: colorPresets

                        Rectangle {
                            width: 26
                            height: 20
                            radius: 3
                            color: modelData.color
                            border.color: index === activePresetIndex ? "#ffffff" : "#555555"
                            border.width: index === activePresetIndex ? 2 : 1

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton)
                                        removePreset(index)
                                    else
                                        selectPreset(index)
                                }
                            }
                        }
                    }
                }
            }
        }
    ]

    function _syncActiveIndex() {
        const target = pickedColor.toString().toLowerCase()
        for (let i = 0; i < colorPresets.length; ++i) {
            if (colorPresets[i].color.toString().toLowerCase() === target) {
                activePresetIndex = i
                return
            }
        }
        activePresetIndex = -1
    }

    function addPresetFromPicker() {
        const c = pickedColor.toString()
        for (let i = 0; i < colorPresets.length; ++i) {
            if (colorPresets[i].color.toString().toLowerCase() === c.toLowerCase()) {
                activePresetIndex = i
                return
            }
        }
        colorPresets = colorPresets.concat([{ color: c }])
        activePresetIndex = colorPresets.length - 1
        saveColorPresets()
    }

    function removePreset(index) {
        if (index < 0 || index >= colorPresets.length) return
        const copy = colorPresets.slice()
        copy.splice(index, 1)
        colorPresets = copy
        _syncActiveIndex()
        saveColorPresets()
    }

    function selectPreset(index) {
        if (index < 0 || index >= colorPresets.length) return
        const c = colorPresets[index].color
        pickedColor = c
        colorPresetSettings.lastColor = c.toString()
        activePresetIndex = index
        control.effectChanged()
    }

    function saveColorPresets() {
        try {
            const data = colorPresets.map(function(p) {
                return { color: p.color.toString() }
            })
            colorPresetSettings.presetsData = JSON.stringify(data)
        } catch (e) {
            console.error("saveColorPresets:", e)
        }
    }

    function loadColorPresets() {
        try {
            if (!colorPresetSettings.presetsData) return false
            const raw = JSON.parse(colorPresetSettings.presetsData)
            const valid = []
            for (let i = 0; i < raw.length; ++i) {
                const entry = raw[i]
                const c = entry.color
                if (c && /^#[0-9a-fA-F]{6,8}$/.test(c))
                    valid.push({ color: c })
            }
            if (valid.length === 0) return false
            colorPresets = valid
            return true
        } catch (e) {
            console.error("loadColorPresets:", e)
            return false
        }
    }
}
