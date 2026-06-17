import QtQuick
import QtQuick.Shapes

/*
 * ScreenEffectOverlay — rendu 2D plein écran d'un ScreenEffect.
 *
 * Calque non interactif posé par-dessus la View3D. Pilote :
 *   - une teinte plate (tintColor à l'opacité `intensity`, atténuée par la part
 *     de vignette),
 *   - une vignette radiale colorée sur les bords (concentration = `vignette`),
 *   - une pulsation optionnelle (`pulseSpeed`),
 * Le tout multiplié par `amount` (facteur de fondu fourni par le contrôleur).
 *
 * La vignette utilise QtQuick.Shapes.RadialGradient (et non Qt5Compat, non
 * installé dans ce kit). Le flou / la désaturation de la scène 3D ne sont PAS
 * faits ici : ils passent par un layer MultiEffect sur la View3D (cf. Editor.qml),
 * car un calque 2D ne peut pas flouter une View3D vivante située dessous.
 */
Item {
    id: root

    /// ScreenEffect à rendre (peut rester non nul pendant un fondu de sortie).
    property var effect: null
    /// Facteur de fondu 0→1 (fourni par ScreenEffectController.amount).
    property real amount: 0.0

    // Ne capte aucun évènement : purement décoratif.
    enabled: false
    visible: amount > 0.001 && effect !== null

    readonly property string _tint:      effect ? effect.tintColor : "transparent"
    readonly property real   _intensity: effect ? effect.intensity : 0
    readonly property real   _vignette:  effect ? effect.vignette  : 0
    readonly property real   _pulse:     (effect && effect.pulseSpeed > 0) ? _pulseValue : 1.0

    function _withAlpha(colStr, a) {
        const c = Qt.color(colStr)
        return Qt.rgba(c.r, c.g, c.b, Math.max(0, Math.min(1, a)))
    }

    // --- Teinte plate (atténuée quand la vignette domine) ---
    Rectangle {
        anchors.fill: parent
        color: root._tint
        opacity: root.amount * root._pulse * root._intensity * (1.0 - root._vignette)
    }

    // --- Vignette radiale colorée sur les bords ---
    Shape {
        id: vignetteShape
        anchors.fill: parent
        visible: root._vignette > 0
        opacity: root.amount * root._pulse
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: vignetteShape.width / 2
                centerY: vignetteShape.height / 2
                focalX: vignetteShape.width / 2
                focalY: vignetteShape.height / 2
                centerRadius: Math.max(vignetteShape.width, vignetteShape.height) * 0.72
                GradientStop { position: 0.0; color: "transparent" }
                GradientStop {
                    // Plus la vignette est forte, plus la couleur démarre tôt.
                    position: root._vignette <= 0
                              ? 1.0
                              : Math.max(0.0, 1.0 - (0.15 + 0.7 * root._vignette))
                    color: "transparent"
                }
                GradientStop { position: 1.0; color: root._withAlpha(root._tint, root._intensity) }
            }

            // Rectangle couvrant tout l'item.
            startX: 0; startY: 0
            PathLine { x: vignetteShape.width; y: 0 }
            PathLine { x: vignetteShape.width; y: vignetteShape.height }
            PathLine { x: 0; y: vignetteShape.height }
            PathLine { x: 0; y: 0 }
        }
    }

    // --- Pulsation ---
    property real _pulseValue: 1.0
    SequentialAnimation on _pulseValue {
        running: root.effect !== null && root.effect.pulseSpeed > 0 && root.amount > 0.01
        loops: Animation.Infinite
        alwaysRunToEnd: true
        NumberAnimation {
            from: 1.0; to: 0.6
            duration: root.effect ? Math.max(120, 700 / Math.max(0.1, root.effect.pulseSpeed)) : 600
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 0.6; to: 1.0
            duration: root.effect ? Math.max(120, 700 / Math.max(0.1, root.effect.pulseSpeed)) : 600
            easing.type: Easing.InOutSine
        }
    }
}
