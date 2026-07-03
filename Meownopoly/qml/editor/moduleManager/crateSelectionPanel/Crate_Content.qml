import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import editorBottomPanel
import theme
import ui_item

/**
 * Panneau du module "Caisses" : configuration des paramètres physiques d'une
 * caisse poussable/attrapable, puis armement de la pose. La pose passe par le
 * chemin UI standard (EM_POSE → TileLogic.placeSelectedAsset, branche
 * cratePoseArmed) pour rester compatible collab/undo.
 *
 * En jeu : la caisse est un body Dynamic (poussable), attrapable avec E si
 * "Attrapable" est coché, et déclenche les zones "plaque de pression".
 *
 * L'édition d'une caisse déjà posée se fait dans le module "config"
 * (CrateConfigurationPanelSection).
 */
EBP_Content {
    id: root

    required property var logic

    readonly property bool isPoseArmed: logic && logic.cratePoseArmed

    signal focusReleased()

    sidePanelRatio: 0

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    // Construit la config de pose depuis l'état courant du formulaire.
    // Les coefficients sont saisis en centièmes (MeowSpinBox est entier) :
    // masse 100 → 1.0, bounce 30 → 0.30, etc.
    function _currentPoseConfig() {
        return {
            mass: massSpin.value / 100.0,
            bounceFactor: bounceSpin.value / 100.0,
            frictionStrength: frictionSpin.value / 100.0,
            linearDamping: dampingSpin.value / 100.0,
            grabbable: grabbableCheck.checked
        }
    }

    ScrollView {
        anchors.fill: parent
        anchors.margins: Theme.spacingL
        clip: true
        contentWidth: mainLayout.width

        RowLayout {
            id: mainLayout
            spacing: Theme.spacingL

            // ==================== COLONNE 1 : PHYSIQUE ====================
            ColumnLayout {
                Layout.preferredWidth: 280
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacingM

                Text {
                    text: "Physique"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                // Coefficients en centièmes (MeowSpinBox entier) : 100 → 1.0.
                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Masse (×0.01)"
                    MeowSpinBox {
                        id: massSpin
                        Layout.fillWidth: true
                        from: 1; to: 1000; stepSize: 10; value: 100
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Rebond (×0.01)"
                    MeowSpinBox {
                        id: bounceSpin
                        Layout.fillWidth: true
                        from: 0; to: 100; stepSize: 5; value: 30
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Friction (×0.01)"
                    MeowSpinBox {
                        id: frictionSpin
                        Layout.fillWidth: true
                        from: 0; to: 100; stepSize: 5; value: 40
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Damping (×0.01)"
                    MeowSpinBox {
                        id: dampingSpin
                        Layout.fillWidth: true
                        from: 0; to: 100; stepSize: 5; value: 10
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Attrapable (E)"
                    MeowCheckBox {
                        id: grabbableCheck
                        checked: true
                    }
                }

                Item { Layout.fillHeight: true }
            }

            Rectangle { Layout.fillHeight: true; width: 1; color: Theme.surfaceHover }

            // ==================== COLONNE 2 : ACTION ====================
            ColumnLayout {
                Layout.preferredWidth: 180
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacingM

                Text {
                    text: "Action"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                MeowButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    iconText: root.isPoseArmed ? "❌" : "📦"
                    text: root.isPoseArmed ? "Annuler" : "Poser une caisse"
                    variant: root.isPoseArmed ? "danger" : "primary"
                    fontSize: Theme.fontSizeMedium
                    hoverZoom: false
                    onClicked: {
                        if (root.isPoseArmed) {
                            logic.clearAssetSelection()
                        } else {
                            logic.armCratePose(root._currentPoseConfig())
                        }
                    }
                }

                MeowInfoBox {
                    Layout.fillWidth: true
                    visible: root.isPoseArmed
                    text: "Cliquez sur la grille pour poser la caisse.\nClic droit pour annuler."
                }

                MeowInfoBox {
                    Layout.fillWidth: true
                    text: "En jeu : poussez la caisse, ou attrapez-la avec E. " +
                          "Poussée dans une zone \"plaque de pression\", elle " +
                          "active les éléments liés (porte, récompense…)."
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
