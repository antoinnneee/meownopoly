import QtQuick
import ui_item

/*
 * Slider étiqueté de l'éditeur d'effets plein écran (screenEffectPanel).
 *
 * Délègue le rendu au MeowSlider canonique (look unifié dans toute l'app) et
 * ré-expose la sémantique transactionnelle attendue par SEP_Content :
 *   - begin()       : début d'un geste (capture du snapshot "avant" pour l'undo/save)
 *   - movedValue(v) : valeur live pendant le drag (aperçu immédiat, sans commit)
 *   - commit()      : fin du geste (persistance d'un seul delta)
 */
MeowSlider {
    id: root

    signal begin()
    signal movedValue(real v)
    signal commit()

    labelWidth: 96
    stepSize: decimals >= 2 ? 0.01 : (decimals === 1 ? 0.1 : 1)

    onGestureBegan: root.begin()
    onMoved: (v) => root.movedValue(v)
    onGestureCommitted: root.commit()
}
