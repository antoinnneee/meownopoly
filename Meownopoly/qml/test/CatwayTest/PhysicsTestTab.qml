import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes
import Pattounx 1.0
import world3d 1.0
import ItemSnapable
import theme

Item {
    id: root
    required property var host

    property string actorId: "p1"
    property string wallId: "wall_east"
    property string trigId: "trig_zone"
    property int eventCount: 0
    property string lastEvent: "—"

    // Visualisation : map id → { points: [Qt.vector2d], exclusion, color }
    // Alimenté par les boutons "Create wall/trigger" (zones de test) et par
    // le bridge ItemSnapableEvents (zones venant de l'éditeur).
    property var viewZones: ({})
    property real pxPerUnit: 32.0
    property int viewTick: 0     // incrémenté pour forcer repaint
    function _bumpView() { root.viewTick++ }
    function _registerViewZone(id, points, exclusion, color) {
        const next = Object.assign({}, root.viewZones)
        next[id] = { points: points, exclusion: exclusion, color: color }
        root.viewZones = next
        _bumpView()
    }
    function _unregisterViewZone(id) {
        if (!root.viewZones[id]) return
        const next = Object.assign({}, root.viewZones)
        delete next[id]
        root.viewZones = next
        _bumpView()
    }

    // Recalcule l'entrée viewZones pour une tile éditeur (PhysicZoneTile).
    function _syncTileToView(tile) {
        if (!tile || tile.tileType !== ItemSnapable.PhysicZoneTile) return
        const zp = tile.zoneParameter
        const dp = tile.displayParameter
        if (!zp || !dp) return
        const local = zp.polygonPoints || []
        if (local.length < 3) { _unregisterViewZone(tile.uniqueId.toString()); return }
        const abs = []
        for (let i = 0; i < local.length; i++)
            abs.push(Qt.vector2d(dp.gridRelativePositionX + local[i].x,
                                 dp.gridRelativePositionY + local[i].y))
        const col = zp.zoneColor && zp.zoneColor !== "" ? zp.zoneColor : "#FF5722"
        _registerViewZone(tile.uniqueId.toString(), abs, zp.exclusion, col)
    }

    Connections {
        target: ItemSnapableEvents
        function onTileCreated(tile) { root._syncTileToView(tile) }
        function onTileMoved(tile) { root._syncTileToView(tile) }
        function onZoneParameterChanged(tile) { root._syncTileToView(tile) }
        function onTileDeleted(tileId, tileType) {
            if (tileType !== ItemSnapable.PhysicZoneTile) return
            root._unregisterViewZone(tileId.toString())
        }
    }

    // Bootstrap : si le tab est ouvert APRÈS la pose de zones dans
    // l'éditeur, ItemSnapableEvents a déjà émis tileCreated et le tab
    // n'était pas là pour l'écouter. On rejoue l'état courant.
    Component.onCompleted: {
        const tiles = ItemSnapableEvents.currentTiles()
        for (let i = 0; i < tiles.length; i++) root._syncTileToView(tiles[i])
        console.log("[PhysicsTestTab] bootstrap: ", tiles.length, "tiles depuis ItemSnapableEvents")
    }

    // Instance globale partagée — exposée par C++ (qmlapp.cpp) via
    // contextProperty `pattounxWorld`. Pas de PhysicsWorld local : sinon
    // le worker thread serait recréé à chaque navigation entre tabs/scènes
    // et il faudrait re-poser zones/bodies à chaque ouverture.
    property var world: pattounxWorld

    Connections {
        target: pattounxWorld
        function onActorEnteredZone(actor, zone) {
            root.eventCount++
            root.lastEvent = "ENTER " + actor + " → " + zone
        }
        function onActorExitedZone(actor, zone) {
            root.eventCount++
            root.lastEvent = "EXIT  " + actor + " ← " + zone
        }
        function onActorCollided(actor, other, normal, speed) {
            root.eventCount++
            root.lastEvent = "HIT   " + actor + " vs " + other
                            + " v=" + speed.toFixed(2)
        }
    }

    // Pas de EditorPhysicsBridge ici : Editor.qml en instancie un sur le
    // même `physicsWorld` global. Ce tab ne fait que visualiser les zones
    // (viewZones tracké directement via ItemSnapableEvents ci-dessous).

    // Pas de stop sur destruction : `physicsWorld` est partagé globalement.
    // L'éditeur ou d'autres consommateurs peuvent en avoir besoin. Le bouton
    // Stop reste disponible si l'utilisateur veut explicitement l'arrêter.

    // FrameAnimation = synchro vsync (~60 Hz sur la plupart des écrans).
    // L'ancien Timer interval=16 (62.5 Hz) battait avec le vsync et
    // produisait un jitter visuel indépendant de la simulation physique.
    FrameAnimation {
        id: refreshTimer
        running: world.running
        property int bodyTick: 0
        onTriggered: {
            world.beginFrame()
            const s = world.bodyState(root.actorId)
            if (s && s.id) {
                positionLabel.text = "pos = ("
                                   + s.position.x.toFixed(2) + ", "
                                   + s.position.y.toFixed(2) + ")"
                                   + "   v = ("
                                   + s.velocity.x.toFixed(2) + ", "
                                   + s.velocity.y.toFixed(2) + ")"
                                   + "   sleep = " + s.isSleeping
            }
            bodyTick++

            if (root._traceFramesLeft > 0) root._logTrace(s)
        }
    }

    // ---- Debug jitter : logger la position physique pendant N frames -----
    // Vise à distinguer (a) jitter côté worker physique [position s/tick]
    // de (b) jitter côté rendu [tick GUI sauté ou doublé].
    property int _traceFramesLeft: 0
    property int _traceFrameIdx: 0
    property real _traceLastMs: 0
    property int _traceLastTick: -1
    property real _traceLastX: 0
    property real _traceLastY: 0

    function startTrace(frames) {
        _traceFramesLeft = frames > 0 ? frames : 180
        _traceFrameIdx   = 0
        _traceLastMs     = Date.now()
        _traceLastTick   = -1
        _traceLastX      = 0
        _traceLastY      = 0
        console.log("[PHYS-TRACE] start frames=" + _traceFramesLeft
                    + " actor=" + root.actorId)
        console.log("[PHYS-TRACE] CSV: frame,tick,dTick,frameMs,"
                    + "px,py,vx,vy,dx,dy,dist")
    }
    function _logTrace(s) {
        const nowMs = Date.now()
        const dtMs  = _traceLastMs > 0 ? (nowMs - _traceLastMs) : 0
        _traceLastMs = nowMs
        const tick = world.currentGuiTick ? world.currentGuiTick() : 0
        const dTick = _traceLastTick < 0 ? 0 : (tick - _traceLastTick)
        _traceLastTick = tick
        const px = s && s.id ? s.position.x : 0
        const py = s && s.id ? s.position.y : 0
        const vx = s && s.id ? s.velocity.x : 0
        const vy = s && s.id ? s.velocity.y : 0
        const dx = px - _traceLastX
        const dy = py - _traceLastY
        const dist = Math.sqrt(dx * dx + dy * dy)
        _traceLastX = px
        _traceLastY = py
        console.log("[PHYS-TRACE] " + _traceFrameIdx
            + "," + tick + "," + dTick + "," + dtMs.toFixed(2)
            + "," + px.toFixed(5) + "," + py.toFixed(5)
            + "," + vx.toFixed(3) + "," + vy.toFixed(3)
            + "," + dx.toFixed(5) + "," + dy.toFixed(5)
            + "," + dist.toFixed(5))
        _traceFrameIdx++
        _traceFramesLeft--
        if (_traceFramesLeft === 0)
            console.log("[PHYS-TRACE] end")
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Theme.spacingXL
        spacing: Theme.spacingXL

        // Header
        RowLayout {
            spacing: Theme.spacingXL
            Layout.fillWidth: true
            Text {
                text: "PattounX v2 — test panel"
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeTitle
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: world.running
                      ? ("● running   tick=" + world.currentTick)
                      : "○ stopped"
                color: world.running ? "#22c55e" : host.textSecondary
                font.pixelSize: Theme.fontSizeBody
            }
        }

        // Lifecycle
        RowLayout {
            spacing: Theme.spacingM
            Button {
                text: "Start"
                enabled: !world.running
                onClicked: world.start()
            }
            Button {
                text: "Stop"
                enabled: world.running
                onClicked: world.stop()
            }
            Button {
                text: "Create actor"
                enabled: world.running
                onClicked: world.createKinematicActor(
                    root.actorId,
                    Qt.vector2d(0, 0),
                    0.3,
                    { acceleration: 50.0, maxSpeed: 8.0, linearDamping: 0.05 })
            }
            Button {
                text: "Create wall (x=4)"
                enabled: world.running
                onClicked: {
                    const points = [
                        Qt.vector2d(4, -3),
                        Qt.vector2d(5, -3),
                        Qt.vector2d(5,  3),
                        Qt.vector2d(4,  3)
                    ]
                    world.upsertZone(root.wallId, points,
                                     { exclusion: true, trigger: false })
                    root._registerViewZone(root.wallId, points, true, "#94a3b8")
                }
            }
            Button {
                text: "Create trigger zone (-3,-3,2x2)"
                enabled: world.running
                onClicked: {
                    const points = [
                        Qt.vector2d(-3, -3),
                        Qt.vector2d(-1, -3),
                        Qt.vector2d(-1, -1),
                        Qt.vector2d(-3, -1)
                    ]
                    world.upsertZone(root.trigId, points,
                                     { exclusion: false, trigger: true,
                                       speedMultiplier: 0.5 })
                    root._registerViewZone(root.trigId, points, false, "#22c55e")
                }
            }
            Button {
                text: "Reset actor pos"
                enabled: world.running
                onClicked: world.setBodyPosition(root.actorId, Qt.vector2d(0, 0))
            }
            Button {
                text: "Trace 3s (jitter)"
                enabled: world.running
                onClicked: root.startTrace(180)
            }
        }

        // Movement controls (simulate input from keyboard)
        GroupBox {
            Layout.fillWidth: true
            title: "Input (ZQSD ou flèches)"
            label: Text {
                text: parent.title
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }
            background: Rectangle { color: host.cardBg; radius: Theme.radiusL;
                                    border.color: host.cardBorder; border.width: 1 }

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacingS
                Text {
                    color: host.textSecondary
                    text: "Cliquez la zone ci-dessous puis utilisez ZQSD/flèches"
                    font.pixelSize: Theme.fontSizeBody
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: focusArea.activeFocus ? "#1e1e26" : "#181820"
                    border.color: focusArea.activeFocus ? host.accent : host.cardBorder
                    border.width: 1
                    radius: Theme.radiusM

                    Text {
                        anchors.centerIn: parent
                        color: host.textSecondary
                        text: focusArea.activeFocus
                              ? "Focus actif — ZQSD/flèches pour bouger"
                              : "Cliquez pour focus"
                        font.pixelSize: Theme.fontSizeBody
                    }

                    MouseArea { anchors.fill: parent; onClicked: focusArea.forceActiveFocus() }

                    Item {
                        id: focusArea
                        anchors.fill: parent
                        focus: true

                        property bool _u: false
                        property bool _d: false
                        property bool _l: false
                        property bool _r: false

                        function _push() {
                            const x = (_r ? 1 : 0) - (_l ? 1 : 0)
                            const y = (_d ? 1 : 0) - (_u ? 1 : 0)
                            let v = Qt.vector2d(x, y)
                            const lenSq = v.x * v.x + v.y * v.y
                            if (lenSq > 1) {
                                const len = Math.sqrt(lenSq)
                                v = Qt.vector2d(v.x / len, v.y / len)
                            }
                            world.pushInput(root.actorId, v)
                        }

                        Keys.onPressed: function(event) {
                            if (event.isAutoRepeat) return
                            switch (event.key) {
                            case Qt.Key_Z: case Qt.Key_Up:    _u = true; break
                            case Qt.Key_S: case Qt.Key_Down:  _d = true; break
                            case Qt.Key_Q: case Qt.Key_Left:  _l = true; break
                            case Qt.Key_D: case Qt.Key_Right: _r = true; break
                            default: return
                            }
                            event.accepted = true
                            _push()
                        }
                        Keys.onReleased: function(event) {
                            if (event.isAutoRepeat) return
                            switch (event.key) {
                            case Qt.Key_Z: case Qt.Key_Up:    _u = false; break
                            case Qt.Key_S: case Qt.Key_Down:  _d = false; break
                            case Qt.Key_Q: case Qt.Key_Left:  _l = false; break
                            case Qt.Key_D: case Qt.Key_Right: _r = false; break
                            default: return
                            }
                            event.accepted = true
                            _push()
                        }
                    }
                }
            }
        }

        // Live state
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 70
            color: host.cardBg
            border.color: host.cardBorder
            border.width: 1
            radius: Theme.radiusL
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.spacingL
                spacing: Theme.spacingXS
                Text {
                    id: positionLabel
                    text: "pos = (?, ?)"
                    color: host.textPrimary
                    font.family: "Consolas"
                    font.pixelSize: Theme.fontSizeBody
                }
                Text {
                    text: "events: " + root.eventCount + "   last: " + root.lastEvent
                            + "   zones: " + Object.keys(root.viewZones).length
                    color: host.textSecondary
                    font.family: "Consolas"
                    font.pixelSize: Theme.fontSizeBody
                }
            }
        }

        // Visualisation 2D top-down (origine au centre, +x = droite, +y = bas)
        GroupBox {
            Layout.fillWidth: true
            Layout.fillHeight: true
            title: "Visualisation 2D — origine au centre"
            label: Text {
                text: parent.title
                color: host.textPrimary
                font.pixelSize: Theme.fontSizeBody
                font.bold: true
            }
            background: Rectangle { color: host.cardBg; radius: Theme.radiusL;
                                    border.color: host.cardBorder; border.width: 1 }

            ColumnLayout {
                anchors.fill: parent
                spacing: Theme.spacingS
                RowLayout {
                    spacing: Theme.spacingM
                    Text {
                        text: "px / unité world : " + root.pxPerUnit.toFixed(0)
                        color: host.textSecondary
                        font.pixelSize: Theme.fontSizeBody
                    }
                    Slider {
                        Layout.preferredWidth: 220
                        from: 4; to: 80; stepSize: 1
                        value: root.pxPerUnit
                        onValueChanged: { root.pxPerUnit = value; root._bumpView() }
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: "● actor   ▰ wall   ▱ trigger"
                        color: host.textSecondary
                        font.pixelSize: Theme.fontSizeSmall
                        font.family: "Consolas"
                    }
                }

                Rectangle {
                    id: vizFrame
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "#0f1015"
                    border.color: host.cardBorder
                    border.width: 1
                    radius: Theme.radiusM
                    clip: true

                    Canvas {
                        id: vizCanvas
                        anchors.fill: parent

                        // Repaint dépendances : viewTick (zones), bodySig (frame physique)
                        property int sigZones: root.viewTick
                        property int sigBody: refreshTimer.bodyTick
                        onSigZonesChanged: requestPaint()
                        onSigBodyChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const w = width, h = height
                            const cx = w / 2, cy = h / 2
                            const k  = root.pxPerUnit

                            function W2P(p) { return Qt.point(cx + p.x * k, cy + p.y * k) }

                            // Grille (1 unit = k px)
                            ctx.strokeStyle = "#1c1d24"
                            ctx.lineWidth = 1
                            const stepW = Math.max(1, Math.floor(w / k) + 2)
                            const stepH = Math.max(1, Math.floor(h / k) + 2)
                            for (let i = -stepW; i <= stepW; i++) {
                                const x = cx + i * k
                                ctx.beginPath(); ctx.moveTo(x, 0); ctx.lineTo(x, h); ctx.stroke()
                            }
                            for (let j = -stepH; j <= stepH; j++) {
                                const y = cy + j * k
                                ctx.beginPath(); ctx.moveTo(0, y); ctx.lineTo(w, y); ctx.stroke()
                            }

                            // Axes
                            ctx.strokeStyle = "#2b2c36"
                            ctx.lineWidth = 1.5
                            ctx.beginPath(); ctx.moveTo(0, cy); ctx.lineTo(w, cy); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(cx, 0); ctx.lineTo(cx, h); ctx.stroke()

                            // Zones
                            const ids = Object.keys(root.viewZones)
                            for (let i = 0; i < ids.length; i++) {
                                const z = root.viewZones[ids[i]]
                                if (!z || !z.points || z.points.length < 3) continue
                                ctx.beginPath()
                                let p0 = W2P(z.points[0])
                                ctx.moveTo(p0.x, p0.y)
                                for (let j = 1; j < z.points.length; j++) {
                                    const pj = W2P(z.points[j])
                                    ctx.lineTo(pj.x, pj.y)
                                }
                                ctx.closePath()
                                // Fill
                                const col = z.color || "#FF5722"
                                ctx.fillStyle = z.exclusion
                                              ? Qt.rgba(0.58, 0.64, 0.72, 0.18)
                                              : Qt.rgba(0.13, 0.77, 0.37, 0.12)
                                ctx.fill()
                                // Stroke
                                ctx.strokeStyle = col
                                ctx.lineWidth = z.exclusion ? 2 : 1.5
                                ctx.stroke()

                                // Label id (tronqué)
                                const lbl = ids[i].length > 10 ? ids[i].substring(0, 10) + "…" : ids[i]
                                ctx.fillStyle = "#cbd5e1"
                                ctx.font = "11px Consolas"
                                ctx.fillText(lbl, p0.x + 4, p0.y - 4)
                            }

                            // Actor
                            const s = world.running ? world.bodyState(root.actorId) : null
                            if (s && s.id) {
                                const ap = W2P(s.position)
                                const r = 0.3 * k  // rayon par défaut de l'actor de test
                                ctx.beginPath()
                                ctx.arc(ap.x, ap.y, r, 0, Math.PI * 2)
                                ctx.fillStyle = s.isColliding ? "#fb7185" : "#60a5fa"
                                ctx.fill()
                                ctx.strokeStyle = "#0b1020"
                                ctx.lineWidth = 1.5
                                ctx.stroke()
                                // Vélocité
                                if (s.velocity) {
                                    const vx = ap.x + s.velocity.x * k * 0.15
                                    const vy = ap.y + s.velocity.y * k * 0.15
                                    ctx.beginPath()
                                    ctx.moveTo(ap.x, ap.y)
                                    ctx.lineTo(vx, vy)
                                    ctx.strokeStyle = "#fde68a"
                                    ctx.lineWidth = 1.5
                                    ctx.stroke()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
