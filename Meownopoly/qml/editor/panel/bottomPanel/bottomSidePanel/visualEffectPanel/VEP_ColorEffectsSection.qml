import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import ui_item
import theme

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

    Timer {
        id: lastColorSaveTimer
        interval: 300
        repeat: false
        onTriggered: colorPresetSettings.lastColor = control.pickedColor.toString()
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
            Layout.topMargin: Theme.spacingM
            topPadding: Theme.spacingXL
            bottomPadding: Theme.spacingS
            leftPadding: Theme.spacingS
            rightPadding: Theme.spacingS
            spacing: Theme.spacingXXS

            background: Rectangle {
                color: "#1a2a2a2a"
                radius: Theme.radiusXS
                border.color: Theme.border
                border.width: 1
            }

            label: Text {
                text: parent.title
                color: Theme.textSecondary
                font.pixelSize: Theme.fontSizeCaption
                font.bold: true
                x: 4
                y: 1
            }

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spacingM

                VEP_InlineColorPicker {
                    id: picker
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    pickedColor: control.pickedColor
                    onColorEdited: function(c) {
                        control.pickedColor = c
                        lastColorSaveTimer.restart()
                        control._syncActiveIndex()
                        control.effectChanged()
                    }
                }

                ColumnLayout {
                    Layout.alignment: Qt.AlignTop
                    Layout.preferredWidth: 92
                    spacing: Theme.spacingXS

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXS

                        Text {
                            text: "Presets"
                            color: Theme.textSecondary
                            font.pixelSize: Theme.fontSizeTiny
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        MeowSwatchButton {
                            text: "+"
                            ToolTip.visible: hovered
                            ToolTip.text: "Save current color"
                            onClicked: addPresetFromPicker()
                        }

                        MeowSwatchButton {
                            text: "×"
                            baseColor: "#aa4444"
                            pressedColor: "#cc4444"
                            ToolTip.visible: hovered
                            ToolTip.text: "Remove selected swatch"
                            enabled: activePresetIndex >= 0
                            onClicked: removePreset(activePresetIndex)
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        spacing: Theme.spacingXS

                        Repeater {
                            model: colorPresets

                            Rectangle {
                                width: 24
                                height: 20
                                radius: Theme.radiusXS
                                color: modelData.color
                                border.color: index === activePresetIndex ? "#ffffff" : Theme.borderLight
                                border.width: index === activePresetIndex ? 2 : 1

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    cursorShape: Qt.PointingHandCursor
                                    ToolTip.visible: containsMouse
                                    ToolTip.text: "Right-click to remove"
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
        }
    ]

    function _syncActiveIndex() {
        for (let i = 0; i < colorPresets.length; ++i) {
            if (Qt.colorEqual(colorPresets[i].color, pickedColor)) {
                activePresetIndex = i
                return
            }
        }
        activePresetIndex = -1
    }

    function addPresetFromPicker() {
        for (let i = 0; i < colorPresets.length; ++i) {
            if (Qt.colorEqual(colorPresets[i].color, pickedColor)) {
                activePresetIndex = i
                return
            }
        }
        colorPresets = colorPresets.concat([{ color: pickedColor.toString() }])
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
        pickedColor = colorPresets[index].color
        lastColorSaveTimer.restart()
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
