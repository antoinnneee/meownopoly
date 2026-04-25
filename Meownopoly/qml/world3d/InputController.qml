/*
 * InputController — Phase 4 (version simple, keymap fixe)
 *
 * Reçoit les évènements clavier et pousse un vecteur d'input normalisé vers
 * `physicsWorld.pushInput(actorId, v)`. Phase 5 introduira la keymap
 * configurable + plusieurs sources (ZQSD vs flèches) + séparation
 * "édition/personnage".
 *
 * Deux moyens de routage :
 *  - via la property `keysHandler` (Item focusable) si on a un parent qui
 *    veut déléguer Keys.onPressed/onReleased ;
 *  - via les fonctions `handlePress(event)` / `handleRelease(event)` à
 *    appeler depuis un Keys.onPressed parent (utilisé dans Editor.qml).
 *
 * Le toggle FreeCam (Key_F) est exposé en signal pour que le rig caméra
 * décide de basculer son mode (séparation des concerns).
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

    // État des touches.
    property bool _u: false
    property bool _d: false
    property bool _l: false
    property bool _r: false

    signal toggleFreeCamRequested()

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
        switch (event.key) {
        case Qt.Key_Z: case Qt.Key_Up:    _u = true; break
        case Qt.Key_S: case Qt.Key_Down:  _d = true; break
        case Qt.Key_Q: case Qt.Key_Left:  _l = true; break
        case Qt.Key_D: case Qt.Key_Right: _r = true; break
        case Qt.Key_Shift: sprint = true; break
        case Qt.Key_F:
            toggleFreeCamRequested()
            return                          // pas de _push pour cette touche
        default: return
        }
        _push()
    }

    function handleRelease(event) {
        if (event.isAutoRepeat) return
        switch (event.key) {
        case Qt.Key_Z: case Qt.Key_Up:    _u = false; break
        case Qt.Key_S: case Qt.Key_Down:  _d = false; break
        case Qt.Key_Q: case Qt.Key_Left:  _l = false; break
        case Qt.Key_D: case Qt.Key_Right: _r = false; break
        case Qt.Key_Shift: sprint = false; break
        default: return
        }
        _push()
    }

    property Item keysHandler: Item {
        focus: true
        Keys.onPressed:  e => root.handlePress(e)
        Keys.onReleased: e => root.handleRelease(e)
    }
}
