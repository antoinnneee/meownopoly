import QtQuick
import ui_item

/*
 * Slider étiqueté du panneau d'effets visuels (visualEffectPanel).
 *
 * Délègue le rendu au MeowSlider canonique (look unifié dans toute l'app) et
 * conserve l'API historique attendue par VEP_ColorEffectsSection /
 * VEP_AdvancedEffectsSection :
 *   - sliderText           : libellé (mappé sur `label`)
 *   - effectChanged(value) : émis à chaque variation de la valeur — drag ET
 *                            affectation programmatique (ex. updateFromDisplayParameter)
 *   - bouton Reset intégré (retour à 0)
 */
MeowSlider {
    id: control

    property string sliderText: ""
    signal effectChanged(var value)

    label: control.sliderText
    labelWidth: Screen.pixelDensity * 17

    from: -1.0
    to: 1.0
    value: 0.0
    stepSize: 0.01

    resettable: true
    resetValue: 0.0

    onValueChanged: control.effectChanged(control.value)
}
