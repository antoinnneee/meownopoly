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
            Layout.topMargin: 8
            topPadding: 14
            bottomPadding: 6
            leftPadding: 6
            rightPadding: 6
            spacing: 2

            background: Rectangle {
                color: "#1a2a2a2a"
                radius: 3
                border.color: "#444444"
                border.width: 1
            }

            label: Text {
                text: parent.title
                color: "#cccccc"
                font.pixelSize: 10
                font.bold: true
                x: 4
                y: 1
            }

            component SwatchButton: Rectangle {
                id: swatchRoot
                property color baseColor: "#4a8a4a"
                property color pressedColor: "#569c58"
                property string text: ""
                signal clicked()
                readonly property alias hovered: swatchMouse.containsMouse
                implicitWidth: 24
                implicitHeight: 22
                radius: 3
                color: swatchRoot.enabled ? (swatchMouse.pressed ? pressedColor : baseColor) : "#444444"
                opacity: swatchRoot.enabled ? 1.0 : 0.55

                Text {
                    anchors.centerIn: parent
                    text: swatchRoot.text
                    color: swatchRoot.enabled ? "#ffffff" : "#888888"
                    font.pixelSize: 14
                    font.bold: true
                }

                MouseArea {
                    id: swatchMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: swatchRoot.clicked()
                }
            }

            RowLayout {
                anchors.fill: parent
                spacing: 8

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
                    spacing: 4

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                            text: "Presets"
                            color: "#cccccc"
                            font.pixelSize: 9
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        SwatchButton {
                            text: "+"
                            ToolTip.visible: hovered
                            ToolTip.text: "Save current color"
                            onClicked: addPresetFromPicker()
                        }

                        SwatchButton {
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
                        spacing: 4

                        Repeater {
                            model: colorPresets

                            Rectangle {
                                width: 24
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
