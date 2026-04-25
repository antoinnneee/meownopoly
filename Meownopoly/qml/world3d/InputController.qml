/*
 * InputController — Phase 5 (keymap configurable)
 *
 * Reçoit les évènements clavier et pousse un vecteur d'input normalisé vers
 * `physicsWorld.pushInput(actorId, v)`.
 *
 * La keymap est exposée en property : par défaut, ZQSD + flèches sont tous
 * deux liés au même actor (compatibilité Phase 4). Pour le multi-joueurs
 * local (Phase 6), instancier deux InputController avec `keymap` distinct
 * (ex: joueur 1 = ZQSD, joueur 2 = flèches). Un même InputController peut
 * écouter plusieurs touches par direction (`up: [Qt.Key_Z, Qt.Key_Up]`).
 *
 * Deux moyens de routage :
 *  - via la property `keysHandler` (Item focusable) si on a un parent qui
 *    veut déléguer Keys.onPressed/onReleased ;
 *  - via les fonctions `handlePress(event)` / `handleRelease(event)` à
 *    appeler depuis un Keys.onPressed parent (utilisé dans Editor.qml).
 *
 * Le toggle FreeCam est exposé en signal pour que le rig caméra
 * décide de basculer son mode (séparation des concerns). La touche
 * associée est elle aussi configurable via `keymap.freeCamToggle`.
 */
import QtQuick

Item {
    id: root

    required property string actorId
    required property var physicsWorld

    // Activation : si false, les events sont ignorés (pas d'input poussé).
    property bool enabled: true

    // Sprint : multiplicateur transmis par pushInput (le moteur n'en tient pas
    // compte par défaut, mais on garde l'état exposé pour le futur).
    property bool sprint: false

    // Keymap par défaut. Chaque entrée peut être une `int` (Qt.Key_X) ou un
    // `array` de `int` pour binder plusieurs touches sur la même action.
    // Override depuis l'extérieur pour le multi-joueurs local :
    //   keymap: ({ up: Qt.Key_Up, down: Qt.Key_Down, left: Qt.Key_Left,
    //              right: Qt.Key_Right, sprint: Qt.Key_Control,
    //              freeCamToggle: -1 })   // -1 = désactivé pour ce joueur
    property var keymap: ({
        up:            [Qt.Key_Z, Qt.Key_Up],
        down:          [Qt.Key_S, Qt.Key_Down],
        left:          [Qt.Key_Q, Qt.Key_Left],
        right:         [Qt.Key_D, Qt.Key_Right],
        sprint:        Qt.Key_Shift,
        freeCamToggle: Qt.Key_F
    })

    // État des touches.
    property bool _u: false
    property bool _d: false
    property bool _l: false
    property bool _r: false

    signal toggleFreeCamRequested()

    // Match d'une touche contre une entrée keymap (int OU array d'int).
    // Centralisé pour éviter de dupliquer la logique press/release.
    function _matches(key, mapping) {
        if (mapping === undefined || mapping === null || mapping === -1)
            return false
        if (Array.isArray(mapping)) return mapping.indexOf(key) !== -1
        return mapping === key
    }

    function _push() {
        if (!physicsWorld || !enabled) return
        let v = Qt.vector2d((_r ? 1 : 0) - (_l ? 1 : 0),
                            (_d ? 1 : 0) - (_u ? 1 : 0))
        const lenSq = v.x * v.x + v.y * v.y
        if (lenSq > 1) {
            const len = Math.sqrt(lenSq)
            v = Qt.vector2d(v.x / len, v.y / len)
        }
        physicsWorld.pushInput(actorId, v)
    }

    // Reset propre des touches (utile quand on perd le focus, ou bascule de
    // mode). Pousse explicitement (0,0) au moteur même si `enabled` est false :
    // sans ça, l'actor garde la dernière input avant la bascule (drift).
    function releaseAll() {
        _u = _d = _l = _r = false
        sprint = false
        if (physicsWorld) physicsWorld.pushInput(actorId, Qt.vector2d(0, 0))
    }

    // `enabled` ne stoppe que le `_push` vers physicsWorld — l'état des
    // touches reste tracké en permanence pour que des consommateurs
    // externes (ex: FreeCam loop) puissent lire `_u/_d/_l/_r`.
    function handlePress(event) {
        if (event.isAutoRepeat) return
        const k = event.key
        if (_matches(k, keymap.up))    { _u = true; _push(); return }
        if (_matches(k, keymap.down))  { _d = true; _push(); return }
        if (_matches(k, keymap.left))  { _l = true; _push(); return }
        if (_matches(k, keymap.right)) { _r = true; _push(); return }
        if (_matches(k, keymap.sprint))        { sprint = true; _push(); return }
        if (_matches(k, keymap.freeCamToggle)) { toggleFreeCamRequested(); return }
    }

    function handleRelease(event) {
        if (event.isAutoRepeat) return
        const k = event.key
        if (_matches(k, keymap.up))    { _u = false; _push(); return }
        if (_matches(k, keymap.down))  { _d = false; _push(); return }
        if (_matches(k, keymap.left))  { _l = false; _push(); return }
        if (_matches(k, keymap.right)) { _r = false; _push(); return }
        if (_matches(k, keymap.sprint)) { sprint = false; _push(); return }
    }

    property Item keysHandler: Item {
        focus: true
        Keys.onPressed:  e => root.handlePress(e)
        Keys.onReleased: e => root.handleRelease(e)
    }
}
