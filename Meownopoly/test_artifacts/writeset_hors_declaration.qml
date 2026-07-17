// Pathologique — écriture d'une clé mémoire HORS write-set déclaré (D11).
//
// Attendu : `writeset_violation` en P4. Le job déclare un write-set
// (`.../state/allowed`) ; le handler écrit une clé `secret` non déclarée, que
// la façade observe et confronte à la déclaration.
import QtQuick

Item {
    id: root

    Component.onCompleted: {
        GameApi.events.on("poke", function(evt) {
            // Écriture d'une clé jamais déclarée dans le write-set du job.
            GameApi.memory.set("secret", 1234);
        });
    }
}
