// Pathologique — Timer 1 ms qui émet un événement à chaque tick.
//
// Attendu : `event_flood` (ou rejet P0 « plancher Timer » en amont, hors banc).
// Mesuré dans la fenêtre d'observation temps réel du banc (500 ms) : le débit
// d'émissions dépasse le plafond D34 (30/s).
import QtQuick

Item {
    id: root

    Timer {
        interval: 1
        repeat: true
        running: true
        onTriggered: GameApi.events.emit("spam", { t: Date.now() })
    }
}
