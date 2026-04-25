import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Pattounx 1.0

Item {
    id: root
    required property var host

    property string actorId: "p1"
    property string wallId: "wall_east"
    property string trigId: "trig_zone"
    property int eventCount: 0
    property string lastEvent: "—"

    PhysicsWorld {
        id: world
        tickRate: 60
        onActorEnteredZone: function(actor, zone) {
            root.eventCount++
            root.lastEvent = "ENTER " + actor + " → " + zone
        }
        onActorExitedZone: function(actor, zone) {
            root.eventCount++
            root.lastEvent = "EXIT  " + actor + " ← " + zone
        }
        onActorCollided: function(actor, other, normal, speed) {
            root.eventCount++
            root.lastEvent = "HIT   " + actor + " vs " + other
                            + " v=" + speed.toFixed(2)
        }
    }

    Component.onDestruction: if (world.running) world.stop()

    Timer {
        id: refreshTimer
        interval: 16
        running: world.running
        repeat: true
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
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12

        // Header
        RowLayout {
            spacing: 12
            Layout.fillWidth: true
            Text {
                text: "PattounX v2 — test panel"
                color: host.textPrimary
                font.pixelSize: 18
                font.bold: true
            }
            Item { Layout.fillWidth: true }
            Text {
                text: world.running
                      ? ("● running   tick=" + world.currentTick)
                      : "○ stopped"
                color: world.running ? "#22c55e" : host.textSecondary
                font.pixelSize: 13
            }
        }

        // Lifecycle
        RowLayout {
            spacing: 8
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
                }
            }
            Button {
                text: "Reset actor pos"
                enabled: world.running
                onClicked: world.setBodyPosition(root.actorId, Qt.vector2d(0, 0))
            }
        }

        // Movement controls (simulate input from keyboard)
        GroupBox {
            Layout.fillWidth: true
            title: "Input (ZQSD ou flèches)"
            label: Text {
                text: parent.title
                color: host.textPrimary
                font.pixelSize: 13
                font.bold: true
            }
            background: Rectangle { color: host.cardBg; radius: 8;
                                    border.color: host.cardBorder; border.width: 1 }

            ColumnLayout {
                anchors.fill: parent
                spacing: 6
                Text {
                    color: host.textSecondary
                    text: "Cliquez la zone ci-dessous puis utilisez ZQSD/flèches"
                    font.pixelSize: 12
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    color: focusArea.activeFocus ? "#1e1e26" : "#181820"
                    border.color: focusArea.activeFocus ? host.accent : host.cardBorder
                    border.width: 1
                    radius: 6

                    Text {
                        anchors.centerIn: parent
                        color: host.textSecondary
                        text: focusArea.activeFocus
                              ? "Focus actif — ZQSD/flèches pour bouger"
                              : "Cliquez pour focus"
                        font.pixelSize: 12
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
            radius: 8
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 4
                Text {
                    id: positionLabel
                    text: "pos = (?, ?)"
                    color: host.textPrimary
                    font.family: "Consolas"
                    font.pixelSize: 13
                }
                Text {
                    text: "events: " + root.eventCount + "   last: " + root.lastEvent
                    color: host.textSecondary
                    font.family: "Consolas"
                    font.pixelSize: 12
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}
