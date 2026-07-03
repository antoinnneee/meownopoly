import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import Game
import EditDelta 1.0
import ItemSnapable
import EditorOpBus 1.0
import theme
import ui_item

/*
 * CrateConfigurationPanelSection — panneau de config de la caisse
 * sélectionnée (module "config", aux côtés de Case/Zone/PNJ/Ennemi).
 *
 * Alimenté par BottomSidePanel.updateSidePanel (sélection simple d'une tile).
 * Chaque édition : mutation directe du PhysicalObjectParameter C++ → op
 * SetPhysicalObjectParameter (collab) + Game.updateMap(TileModified)
 * débouncé (persistance/undo).
 */
CollapsableGroupBox {
    id: root
    title: "Configuration de caisse"

    property bool updatingValues: false
    property var logic: null

    // ItemSnapable C++ de la caisse ciblée (null si sélection ≠ 1 caisse).
    property var targetSnapable: null
    readonly property var targetCrate: targetSnapable ? targetSnapable.physicalObjectParameter : null

    signal focusReleased()

    // Renseigné par updateSidePanel : cible ou efface selon le tileType.
    function setTargetCrate(snapableParameter) {
        if (snapableParameter && snapableParameter.tileType === ItemSnapable.PhysicalObjectTile) {
            targetSnapable = snapableParameter
            updatingValues = true
            const c = snapableParameter.physicalObjectParameter
            massSpin.value = Math.round(c.mass * 100)
            bounceSpin.value = Math.round(c.bounceFactor * 100)
            frictionSpin.value = Math.round(c.frictionStrength * 100)
            dampingSpin.value = Math.round(c.linearDamping * 100)
            grabbableCheck.checked = c.grabbable
            updatingValues = false
        } else {
            targetSnapable = null
        }
    }

    // Commit débouncé : une rafale d'éditions ne produit qu'un TileModified.
    Timer {
        id: commitDelayer
        interval: 200
        onTriggered: {
            if (!root.targetSnapable) return
            Game.updateMap(EditDelta.TileModified, root.targetSnapable)
        }
    }

    function _applyFormFields() {
        if (!targetCrate || updatingValues) return
        targetCrate.mass = massSpin.value / 100.0
        targetCrate.bounceFactor = bounceSpin.value / 100.0
        targetCrate.frictionStrength = frictionSpin.value / 100.0
        targetCrate.linearDamping = dampingSpin.value / 100.0
        targetCrate.grabbable = grabbableCheck.checked
        EditorOpBus.recordOp(EditorOpBus.makeSetPhysicalObjectParameterOp(
            String(targetSnapable.uniqueId),
            JSON.parse(targetCrate.toJSON())))
        commitDelayer.restart()
    }

    content: [
        Text {
            visible: root.targetSnapable === null
            text: "Sélectionnez une caisse pour la configurer."
            color: Theme.textMuted
            font.pixelSize: Theme.fontSizeSmall
            font.italic: true
        },

        ColumnLayout {
            visible: root.targetSnapable !== null
            Layout.fillWidth: true
            spacing: Theme.spacingS

            // Coefficients en centièmes (MeowSpinBox entier) : 100 → 1.0.
            MeowPropertyRow {
                Layout.fillWidth: true
                label: "Masse (×0.01)"
                MeowSpinBox {
                    id: massSpin
                    Layout.fillWidth: true
                    from: 1; to: 1000; stepSize: 10; value: 100
                    onValueChanged: if (!root.updatingValues) root._applyFormFields()
                }
            }

            MeowPropertyRow {
                Layout.fillWidth: true
                label: "Rebond (×0.01)"
                MeowSpinBox {
                    id: bounceSpin
                    Layout.fillWidth: true
                    from: 0; to: 100; stepSize: 5; value: 30
                    onValueChanged: if (!root.updatingValues) root._applyFormFields()
                }
            }

            MeowPropertyRow {
                Layout.fillWidth: true
                label: "Friction (×0.01)"
                MeowSpinBox {
                    id: frictionSpin
                    Layout.fillWidth: true
                    from: 0; to: 100; stepSize: 5; value: 40
                    onValueChanged: if (!root.updatingValues) root._applyFormFields()
                }
            }

            MeowPropertyRow {
                Layout.fillWidth: true
                label: "Damping (×0.01)"
                MeowSpinBox {
                    id: dampingSpin
                    Layout.fillWidth: true
                    from: 0; to: 100; stepSize: 5; value: 10
                    onValueChanged: if (!root.updatingValues) root._applyFormFields()
                }
            }

            MeowPropertyRow {
                Layout.fillWidth: true
                label: "Attrapable (E)"
                MeowCheckBox {
                    id: grabbableCheck
                    checked: true
                    onCheckedChanged: if (!root.updatingValues) root._applyFormFields()
                }
            }
        }
    ]
}
