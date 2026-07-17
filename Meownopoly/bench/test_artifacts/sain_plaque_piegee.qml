// Corpus banc d'essai (doc/v3/12_BANC_ESSAI_R1.md §8) — cas SAIN, fil rouge
// du vertical slice (doc 11) : plaque piégée qui ralentit le premier joueur
// entrant dans sa zone. Attendu : pass P0, pass banc, metrics dans les budgets.
// Façade Meow.GameApi conforme D34 : memory.get/set, events.on/emit,
// stats.addModifier. requiresModules attendu : ["stats"].
import QtQuick
import Meow.GameApi

Item {
    id: root

    Component.onCompleted: {
        // Armée par défaut ; l'état survit dans l'espace mémoire de la tuile.
        if (memory.get("state/armed") === undefined)
            memory.set("state/armed", true)

        events.on("zoneEntered", function (ev) {
            if (!memory.get("state/armed"))
                return
            memory.set("state/armed", false)
            // Malus de vitesse temporaire (module gameplay "stats", D41).
            stats.addModifier(ev.playerId, "speed", -0.5, 3000)
            events.emit("trapTriggered", { playerId: ev.playerId })
        })
    }
}
