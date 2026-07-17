// Corpus banc d'essai (doc 12 §8) — fuite au teardown : Timer jamais arrêté
// ni désinscription des événements. Attendu : PASSE P0 (interval 500 ms ≥
// plancher D34), puis `leak` en P5 au banc (timer/connexions survivants à la
// destruction de l'artefact).
import QtQuick
import Meow.GameApi

Item {
    id: root

    Timer {
        id: pulse
        interval: 500
        running: true
        repeat: true
        onTriggered: events.emit("pulse", {})
    }

    Component.onCompleted: {
        events.on("zoneEntered", function (ev) {
            memory.set("state/lastVisitor", ev.playerId)
        })
    }

    Component.onDestruction: {
        // Oubli volontaire : pulse.running n'est pas remis à false et aucune
        // désinscription events n'est faite — c'est la fuite testée en P5.
    }
}
