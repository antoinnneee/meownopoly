// Pathologique — activité de façade au teardown (objet/handler survivant).
//
// Attendu : `leak` en P5. Le banc détruit l'artefact puis observe toute
// activité résiduelle de la façade. Ici, l'artefact touche encore la façade au
// moment de sa destruction (`Component.onDestruction`) — signature d'un objet
// qui ne se laisse pas ramasser proprement (Timer/connexion survivant).
import QtQuick

Item {
    id: root

    // Un Timer qui tourne pendant toute la vie de l'artefact.
    Timer {
        id: heartbeat
        interval: 50
        repeat: true
        running: true
        onTriggered: {} // bruit de fond, sans émission (n'émarge pas au flood)
    }

    // Au démontage, l'artefact continue de solliciter la façade : c'est
    // exactement ce que le détecteur de fuite P5 flague (activité après la
    // capture de référence pré-teardown).
    Component.onDestruction: {
        GameApi.events.emit("adieu");
        GameApi.memory.set("fuite", Date.now());
    }
}
