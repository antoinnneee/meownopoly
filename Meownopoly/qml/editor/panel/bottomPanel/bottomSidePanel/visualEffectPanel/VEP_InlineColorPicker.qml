import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

Item {
    id: root

    property color pickedColor: "#ffffff"
    signal colorEdited(color c)

    // 0 = Classic (hue ring + SV square), 1 = HSV (disk + value slider)
    property int mode: 0

    property real _hue: 0
    property real _sat: 0
    property real _val: 1
    property bool _applying: false
    property bool _eyedropperActive: false

    function _startEyedropper() {
        if (!root.Window.window) return
        root._eyedropperActive = true
    }

    function _cancelEyedropper() {
        root._eyedropperActive = false
    }

    function _performPick(xWin, yWin) {
        // Build ancestor chain (root → top)
        const chain = []
        let item = root
        while (item) { chain.push(item); item = item.parent }

        // Walk from the highest user-declared ancestor down to the picker.
        // Skip the last 2 entries which are typically Qt internal items
        // (QQuickContentItem + QQuickRootItem) that reject grabToImage.
        // Try each candidate until grabToImage returns true.
        for (let idx = Math.max(0, chain.length - 3); idx >= 0; --idx) {
            const target = chain[idx]
            if (!target || target.width <= 0 || target.height <= 0) continue

            const localPos = target.mapFromItem(null, xWin, yWin)
            if (localPos.x < 0 || localPos.y < 0 ||
                localPos.x >= target.width || localPos.y >= target.height) continue

            const tw = target.width, th = target.height
            const lx = localPos.x, ly = localPos.y
            const ok = target.grabToImage(function(result) {
                if (!result || !result.url) return
                pixelReader.width = tw
                pixelReader.height = th
                pixelReader._clickX = lx
                pixelReader._clickY = ly
                pixelReader._imageUrl = result.url
                pixelReader.loadImage(result.url)
            }, Qt.size(tw, th))

            if (ok) { root._cancelEyedropper(); return }
        }
        root._cancelEyedropper()
    }

    Canvas {
        id: pixelReader
        visible: false
        renderTarget: Canvas.Image
        property string _imageUrl: ""
        property real _clickX: 0
        property real _clickY: 0

        onImageLoaded: requestPaint()
        onPaint: {
            if (!_imageUrl) return
            const ctx = getContext("2d")
            ctx.drawImage(_imageUrl, 0, 0)
            try {
                const d = ctx.getImageData(_clickX, _clickY, 1, 1).data
                const c = Qt.rgba(d[0] / 255, d[1] / 255, d[2] / 255, 1)
                root.colorEdited(c)
            } catch (e) {
                console.error("Eyedropper pick failed:", e)
            }
            _imageUrl = ""
        }
    }

    Loader {
        active: root._eyedropperActive
        parent: Overlay.overlay
        x: 0
        y: 0
        width: parent ? parent.width : 0
        height: parent ? parent.height : 0
        z: 99999
        sourceComponent: MouseArea {
            cursorShape: Qt.CrossCursor
            hoverEnabled: true
            focus: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            Component.onCompleted: forceActiveFocus()

            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.color: "#4a8a4a"
                border.width: 2
            }

            onClicked: function(mouse) {
                if (mouse.button === Qt.RightButton)
                    root._cancelEyedropper()
                else
                    root._performPick(mouse.x, mouse.y)
            }
            Keys.onEscapePressed: root._cancelEyedropper()
        }
    }

    implicitHeight: layout.implicitHeight
    implicitWidth: 180

    onPickedColorChanged: {
        _fromColor(pickedColor)
        if (hexField && !hexField.activeFocus)
            hexField.text = pickedColor.toString().toUpperCase()
    }
    Component.onCompleted: _fromColor(pickedColor)

    function _emit() {
        if (_applying) return
        _applying = true
        const c = Qt.hsva(_hue, _sat, _val, 1)
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

    function _hsvToRgb(h, s, v) {
        const i = Math.floor(h * 6)
        const f = h * 6 - i
        const p = v * (1 - s)
        const q = v * (1 - f * s)
        const t = v * (1 - (1 - f) * s)
        let r = 0, g = 0, b = 0
        switch (i % 6) {
            case 0: r = v; g = t; b = p; break
            case 1: r = q; g = v; b = p; break
            case 2: r = p; g = v; b = t; break
            case 3: r = p; g = q; b = v; break
            case 4: r = t; g = p; b = v; break
            case 5: r = v; g = p; b = q; break
        }
        return [r * 255 | 0, g * 255 | 0, b * 255 | 0]
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        spacing: 6

        // Mode toggle
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [
                    { label: "Classic", value: 0 },
                    { label: "HSV",     value: 1 }
                ]

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    readonly property bool isChecked: root.mode === modelData.value
                    color: isChecked ? "#4a8a4a"
                                     : (modeMouse.containsMouse ? "#3a3a3a" : "#2d2d2d")
                    border.color: isChecked ? "#6bcf6d" : "#555"
                    border.width: 1
                    radius: 3

                    Text {
                        anchors.centerIn: parent
                        text: modelData.label
                        color: parent.isChecked ? "#ffffff" : "#cccccc"
                        font.pixelSize: 12
                        font.bold: parent.isChecked
                    }

                    MouseArea {
                        id: modeMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.mode = modelData.value
                    }
                }
            }
        }

        // Picker area (circle + optional V slider)
        Item {
            id: pickerArea
            Layout.fillWidth: true
            Layout.preferredHeight: 150

            readonly property real vSliderW: root.mode === 1 ? 16 : 0
            readonly property real vSliderGap: root.mode === 1 ? 6 : 0
            readonly property real diameter: Math.max(40, Math.min(width - vSliderW - vSliderGap, height))
            readonly property real circleX: (width - diameter - vSliderW - vSliderGap) / 2
            readonly property real circleY: (height - diameter) / 2

            // ------------------ CLASSIC MODE : hue ring + SV square
            Item {
                id: classicMode
                opacity: root.mode === 0 ? 1 : 0
                enabled: root.mode === 0
                x: pickerArea.circleX
                y: pickerArea.circleY
                width: pickerArea.diameter
                height: pickerArea.diameter

                readonly property real outerR: Math.min(width, height) / 2 - 1
                readonly property real ringW: 14
                readonly property real innerR: outerR - ringW
                readonly property real squareSide: innerR * Math.SQRT2 * 0.92

                Canvas {
                    id: hueRingCanvas
                    anchors.fill: parent
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        const cx = width / 2, cy = height / 2
                        const rOut = classicMode.outerR
                        const rIn  = classicMode.innerR
                        const slices = 720
                        const a0base = -Math.PI / 2
                        for (let i = 0; i < slices; ++i) {
                            const a0 = a0base + (i / slices) * 2 * Math.PI
                            const a1 = a0base + ((i + 1) / slices) * 2 * Math.PI + 0.008
                            ctx.beginPath()
                            ctx.arc(cx, cy, rOut, a0, a1, false)
                            ctx.arc(cx, cy, rIn,  a1, a0, true)
                            ctx.closePath()
                            const rgb = root._hsvToRgb(i / slices, 1, 1)
                            ctx.fillStyle = "rgb(" + rgb[0] + "," + rgb[1] + "," + rgb[2] + ")"
                            ctx.fill()
                        }
                    }
                }

                // Hue indicator on the ring
                Rectangle {
                    width: classicMode.ringW + 6
                    height: width
                    radius: height / 2
                    color: "transparent"
                    border.color: "white"
                    border.width: 2
                    readonly property real ang: root._hue * 2 * Math.PI - Math.PI / 2
                    readonly property real rMid: classicMode.outerR - classicMode.ringW / 2
                    x: classicMode.width / 2 + rMid * Math.cos(ang) - width / 2
                    y: classicMode.height / 2 + rMid * Math.sin(ang) - height / 2
                }

                // MouseArea for hue ring (under SV square)
                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    property bool dragging: false
                    onPressed: function(m) {
                        const cx = classicMode.width / 2
                        const cy = classicMode.height / 2
                        const dx = m.x - cx, dy = m.y - cy
                        const d = Math.sqrt(dx * dx + dy * dy)
                        if (d < classicMode.innerR - 2 || d > classicMode.outerR + 2) {
                            m.accepted = false
                            return
                        }
                        dragging = true
                        updateHue(m.x, m.y)
                    }
                    onReleased: dragging = false
                    onCanceled: dragging = false
                    onPositionChanged: function(m) { if (dragging) updateHue(m.x, m.y) }
                    function updateHue(mx, my) {
                        const cx = classicMode.width / 2
                        const cy = classicMode.height / 2
                        let a = Math.atan2(my - cy, mx - cx) + Math.PI / 2
                        if (a < 0) a += 2 * Math.PI
                        if (a >= 2 * Math.PI) a -= 2 * Math.PI
                        root._hue = a / (2 * Math.PI)
                        root._emit()
                    }
                }

                // SV square inscribed (declared last → topmost for events)
                Rectangle {
                    id: svSquare
                    width: classicMode.squareSide
                    height: classicMode.squareSide
                    anchors.centerIn: parent
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
                        width: 10; height: 10; radius: 5
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
            }

            // ------------------ HSV MODE : full disk + value slider
            Item {
                id: hsvMode
                opacity: root.mode === 1 ? 1 : 0
                enabled: root.mode === 1
                x: pickerArea.circleX
                y: pickerArea.circleY
                width: pickerArea.diameter
                height: pickerArea.diameter

                Canvas {
                    id: hsvDiskCanvas
                    anchors.fill: parent
                    renderTarget: Canvas.Image
                    onWidthChanged: requestPaint()
                    onHeightChanged: requestPaint()
                    Component.onCompleted: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        const cx = width / 2, cy = height / 2
                        const maxR = Math.min(cx, cy) - 1
                        if (maxR < 2) return

                        const slices = 360
                        const baseAngle = -Math.PI / 2
                        const sliceAng = (2 * Math.PI) / slices
                        for (let i = 0; i < slices; ++i) {
                            const a0 = baseAngle + i * sliceAng
                            const a1 = baseAngle + (i + 1) * sliceAng + 0.015
                            ctx.beginPath()
                            ctx.moveTo(cx, cy)
                            ctx.arc(cx, cy, maxR, a0, a1)
                            ctx.closePath()
                            const rgb = root._hsvToRgb(i / slices, 1, 1)
                            ctx.fillStyle = "rgb(" + rgb[0] + "," + rgb[1] + "," + rgb[2] + ")"
                            ctx.fill()
                        }

                        const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, maxR)
                        grad.addColorStop(0, "rgba(255, 255, 255, 1)")
                        grad.addColorStop(1, "rgba(255, 255, 255, 0)")
                        ctx.fillStyle = grad
                        ctx.beginPath()
                        ctx.arc(cx, cy, maxR, 0, 2 * Math.PI)
                        ctx.closePath()
                        ctx.fill()
                    }
                }

                // Darkening overlay that follows the value slider
                Rectangle {
                    anchors.fill: hsvDiskCanvas
                    color: "#000000"
                    radius: width / 2
                    opacity: 1 - root._val
                }

                Rectangle {
                    id: hsvIndicator
                    width: 10; height: 10; radius: 5
                    color: "transparent"
                    border.color: "white"; border.width: 2
                    readonly property real maxR: Math.min(hsvMode.width, hsvMode.height) / 2 - 1
                    readonly property real ang: root._hue * 2 * Math.PI - Math.PI / 2
                    x: hsvMode.width / 2 + root._sat * maxR * Math.cos(ang) - width / 2
                    y: hsvMode.height / 2 + root._sat * maxR * Math.sin(ang) - height / 2
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: function(m) { update(m.x, m.y) }
                    onPositionChanged: function(m) { if (pressed) update(m.x, m.y) }
                    function update(mx, my) {
                        const cx = hsvMode.width / 2
                        const cy = hsvMode.height / 2
                        const dx = mx - cx, dy = my - cy
                        const d = Math.sqrt(dx * dx + dy * dy)
                        const R = Math.min(cx, cy) - 1
                        let a = Math.atan2(dy, dx) + Math.PI / 2
                        if (a < 0) a += 2 * Math.PI
                        if (a >= 2 * Math.PI) a -= 2 * Math.PI
                        root._hue = a / (2 * Math.PI)
                        root._sat = Math.max(0, Math.min(1, d / R))
                        root._emit()
                    }
                }
            }

            // Vertical value slider (HSV mode only)
            Rectangle {
                id: vBar
                visible: root.mode === 1
                x: pickerArea.circleX + pickerArea.diameter + pickerArea.vSliderGap
                y: pickerArea.circleY
                width: 16
                height: pickerArea.diameter
                radius: 3
                border.color: "#555"
                border.width: 1
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.hsva(root._hue, root._sat, 1, 1) }
                    GradientStop { position: 1; color: "#000000" }
                }

                Rectangle {
                    width: vBar.width + 6; height: 3
                    x: -3
                    y: (1 - root._val) * vBar.height - height / 2
                    color: "white"
                    border.color: "#222"; border.width: 1
                    radius: 1
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                    onPressed: function(m) { update(m.y) }
                    onPositionChanged: function(m) { if (pressed) update(m.y) }
                    function update(my) {
                        root._val = Math.max(0, Math.min(1, 1 - my / vBar.height))
                        root._emit()
                    }
                }
            }
        }

        // Color preview + hex field + eyedropper
        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
                Layout.preferredWidth: 28
                Layout.preferredHeight: 28
                radius: 3
                color: root.pickedColor
                border.color: "#666"; border.width: 1
            }

            // TODO: Eyedropper button disabled — grabToImage fails with
            // "QQuickRootItem: item has no QML engine" when walking up the
            // ApplicationWindow hierarchy. Re-enable once a working grab
            // target strategy (or C++ helper) is in place.
            Rectangle {
                visible: false
                Layout.preferredWidth: 0
                Layout.preferredHeight: 0
                radius: 3
                color: root._eyedropperActive ? "#569c58"
                        : (eyedropMouse.pressed ? "#569c58"
                        : (eyedropMouse.containsMouse ? "#4a8a4a" : "#3a3a3a"))
                border.color: root._eyedropperActive ? "#6bcf6d" : "#555"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "🎨"
                    font.pixelSize: 14
                }

                MouseArea {
                    id: eyedropMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._startEyedropper()
                    ToolTip.visible: containsMouse
                    ToolTip.text: "Pick color from screen (Esc to cancel)"
                }
            }

            TextField {
                id: hexField
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: "#ffffff"
                font.pixelSize: 13
                font.family: "monospace"
                font.bold: true
                selectByMouse: true
                placeholderText: "#rrggbb"
                placeholderTextColor: "#666"
                text: root.pickedColor.toString().toUpperCase()
                verticalAlignment: TextInput.AlignVCenter
                topPadding: 0
                bottomPadding: 0
                leftPadding: 8
                rightPadding: 8
                background: Rectangle {
                    color: "#2a2a2a"
                    radius: 3
                    border.color: hexField.activeFocus ? "#6bcf6d" : "#555"
                    border.width: 1
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
}
