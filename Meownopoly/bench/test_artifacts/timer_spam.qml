// Corpus banc d'essai (doc 12 §8) — Timer 1 ms + émission d'événement.
// Attendu : REJET P0 `timer_interval_too_low` (plancher D34 : Timer ≥ 100 ms,
// appliqué statiquement aux intervalles LITTÉRAUX — choix d'implémentation
// A4). Un interval calculé passerait P0 et serait attrapé au banc en P4
// (`event_flood`, > 30 émissions/s).
import QtQuick
import Meow.GameApi

Item {
    Timer {
        interval: 1
        running: true
        repeat: true
        onTriggered: events.emit("spam", {})
    }
}
