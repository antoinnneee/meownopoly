import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root

    property color pickedColor: "#ffffff"
    signal colorEdited(color c)

    property real _hue: 0
    property real _sat: 0
    property real _val: 1
    property bool _applying: false

    implicitHeight: layout.implicitHeight
    implicitWidth: 200

    onPickedColorChanged: _fromColor(pickedColor)
    Component.onCompleted: _fromColor(pickedColor)

    function _emit() {
        if (_applying) return
        _applying = true
        const c = Qt.hsva(_hue, _sat, _val, 1)
        pickedColor = c
        root.colorEdited(c)
        _applying = false
    }

    function _fromColor(c) {
        if (_applying) return
        _applying = true
        const r = c.r, g = c.g, b = c.b
        const max = Math.max(r, g, b)
        const min = Math.min(r, g, b)
        const d = max - min
        let h = 0
        const s = max === 0 ? 0 : d / max
        const v = max
        if (d !== 0) {
            if (max === r) h = (g - b) / d + (g < b ? 6 : 0)
            else if (max === g) h = (b - r) / d + 2
            else h = (r - g) / d + 4
            h /= 6
        } else {
            h = _hue
        }
        _hue = h
        _sat = s
        _val = v
        _applying = false
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 6

        Rectangle {
            id: svSquare
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            color: Qt.hsva(root._hue, 1, 1, 1)
            border.color: "#555"
            border.width: 1
            radius: 2
            clip: true

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "#ffffffff" }
                    GradientStop { position: 1.0; color: "#00ffffff" }
                }
            }

            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#00000000" }
                    GradientStop { position: 1.0; color: "#ff000000" }
                }
            }

            Rectangle {
                width: 12; height: 12; radius: 6
                border.color: "white"; border.width: 2
                color: "transparent"
                x: root._sat * svSquare.width - width / 2
                y: (1 - root._val) * svSquare.height - height / 2
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: function(m) { update(m.x, m.y) }
                onPositionChanged: function(m) { if (pressed) update(m.x, m.y) }
                function update(mx, my) {
                    root._sat = Math.max(0, Math.min(1, mx / svSquare.width))
                    root._val = Math.max(0, Math.min(1, 1 - my / svSquare.height))
                    root._emit()
                }
            }
        }

        Rectangle {
            id: hueBar
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            radius: 3
            border.color: "#555"
            border.width: 1
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.000; color: "#ff0000" }
                GradientStop { position: 0.166; color: "#ffff00" }
                GradientStop { position: 0.333; color: "#00ff00" }
                GradientStop { position: 0.500; color: "#00ffff" }
                GradientStop { position: 0.666; color: "#0000ff" }
                GradientStop { position: 0.833; color: "#ff00ff" }
                GradientStop { position: 1.000; color: "#ff0000" }
            }

            Rectangle {
                width: 4; height: hueBar.height + 6; y: -3
                x: root._hue * hueBar.width - width / 2
                color: "white"
                border.color: "#222"; border.width: 1
                radius: 1
            }

            MouseArea {
                anchors.fill: parent
                preventStealing: true
                onPressed: function(m) { update(m.x) }
                onPositionChanged: function(m) { if (pressed) update(m.x) }
                function update(mx) {
                    root._hue = Math.max(0, Math.min(0.9999, mx / hueBar.width))
                    root._emit()
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 22
                radius: 3
                color: root.pickedColor
                border.color: "#666"; border.width: 1
            }

            TextField {
                id: hexField
                Layout.fillWidth: true
                Layout.preferredHeight: 22
                color: "#cccccc"
                font.pixelSize: 11
                font.family: "monospace"
                selectByMouse: true
                placeholderText: "#rrggbb"
                text: root.pickedColor.toString().toUpperCase()
                background: Rectangle {
                    color: "#3a3a3a"; radius: 3
                    border.color: "#555"; border.width: 1
                }
                onEditingFinished: commit()
                Keys.onReturnPressed: commit()
                Keys.onEnterPressed: commit()
                function commit() {
                    let t = text.trim()
                    if (!t.startsWith("#")) t = "#" + t
                    if (/^#[0-9a-fA-F]{6}$/.test(t)) {
                        root._fromColor(Qt.color(t))
                        root._emit()
                    } else {
                        text = root.pickedColor.toString().toUpperCase()
                    }
                }
            }
        }
    }

    Connections {
        target: root
        function onPickedColorChanged() {
            if (!hexField.activeFocus)
                hexField.text = root.pickedColor.toString().toUpperCase()
        }
    }
}
