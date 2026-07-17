// Fil rouge (doc v3 11) — artefact SAIN de référence.
//
// Attendu : `pass`, toutes les métriques dans les budgets D34.
// C'est le critère R1 n°5 : si cet artefact devient instable, le banc rejette
// du code correct et l'itération S3 est impossible.
//
// « Plaque piégée » : à l'entrée d'un joueur dans la zone, on lit le score en
// mémoire propriétaire, on applique un modificateur de stat, on ré-écrit le
// score. Toutes les écritures restent dans le write-set déclaré (state/score).
import QtQuick

Item {
    id: root

    Component.onCompleted: {
        // Abonnement à l'entrée de zone (surface events.on, D34).
        GameApi.events.on("zoneEntered", function(evt) {
            const actor = evt && evt.actorId ? evt.actorId : "inconnu";
            // Lecture mémoire propriétaire (namespace state).
            let score = GameApi.memory.get("score");
            if (typeof score !== "number")
                score = 0;
            score += 10;
            // Effet gameplay (enregistré ; branchement réel = S-6).
            GameApi.stats.addModifier(actor, "speed", -0.2);
            // Écriture mémoire — clé DÉCLARÉE dans le write-set du job.
            GameApi.memory.set("score", score);
        });
    }
}
