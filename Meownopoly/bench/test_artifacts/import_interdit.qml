// Corpus banc d'essai (doc 12 §8) — import réseau interdit.
// Attendu : REJET P0 `import_forbidden` (QtWebSockets est dans les interdits
// explicites D34), le banc n'est jamais spawné.
import QtQuick
import QtWebSockets

Item {
    WebSocket {
        url: "ws://example.invalid:1234"
        active: true
    }
}
