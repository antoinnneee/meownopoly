import QtQuick
import QtQuick.Controls
import visualEffectPanel

// Onglet « Visuel » : réutilise le VisualEffectsPanel existant tel quel
// (mêmes sections VEP_*), déplié par défaut. Contrat commun des onglets :
// setTarget(element) / clearTarget(), signaux relayés vers InspectorPanel.
ScrollView {
    id: root

    signal effectChanged()

    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    contentWidth: availableWidth
    clip: true

    function setTarget(element) {
        if (!element || !element.snapableParameters
                || !element.snapableParameters.displayParameter) {
            clearTarget()
            return
        }
        effectsPanel.updateFromDisplayParameter(
                    element.snapableParameters.displayParameter)
    }

    function clearTarget() {
        // rien à purger : le panel garde ses dernières valeurs, il est
        // masqué avec l'inspecteur quand la sélection est vide.
    }

    // Même contrat que editorSidePanel.visualEffectsPanel — consommé par le
    // flush d'ops SetDisplayParameter dans Editor.qml.
    function getCurrentEffects() {
        return effectsPanel.getCurrentEffects()
    }

    VisualEffectsPanel {
        id: effectsPanel
        width: root.availableWidth
        isCollapsed: false
        onEffectChanged: root.effectChanged()
    }
}
