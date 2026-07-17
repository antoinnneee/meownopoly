// Corpus banc d'essai (doc 12 §8) — boucle infinie dans un handler
// d'événement. Attendu : PASSE P0, puis `event_budget`/`bench_timeout` en P4
// (le handler ne rend jamais la main quand le stimulus zoneEntered est joué).
import QtQuick
import Meow.GameApi

Item {
    Component.onCompleted: {
        events.on("zoneEntered", function (ev) {
            let total = 0
            while (true) {
                total = total + ev.playerId.length
            }
        })
    }
}
