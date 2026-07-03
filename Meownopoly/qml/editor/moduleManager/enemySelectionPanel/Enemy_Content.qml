import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import editorBottomPanel
import AssetManager
import theme
import ui_item

/**
 * Panneau du module "Ennemis" : configuration de l'identité (nom + modèle 3D)
 * et des statistiques de combat, puis armement de la pose. La pose passe par
 * le chemin UI standard (EM_POSE → TileLogic.placeSelectedAsset, branche
 * enemyPoseArmed) pour rester compatible collab/undo.
 *
 * L'édition d'un ennemi déjà posé se fait dans le module "config"
 * (EnemyConfigurationPanelSection / sections ECP_*).
 */
EBP_Content {
    id: root

    required property var logic

    readonly property bool isPoseArmed: logic && logic.enemyPoseArmed

    signal focusReleased()

    sidePanelRatio: 0

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    // Construit la config de pose depuis l'état courant du formulaire.
    function _currentPoseConfig() {
        return {
            enemyName: nameInput.text,
            modelName: modelCombo.currentText,
            maxHp: maxHpSpin.value,
            attackDamage: damageSpin.value,
            attackRange: rangeSpin.value / 10.0,
            attackCooldownMs: cooldownSpin.value,
            aggroRange: aggroSpin.value / 10.0,
            moveSpeed: speedSpin.value / 10.0,
            lootCurrency: lootCurrencySpin.value,
            lootItemName: lootItemField.text,
            lootItemQuantity: lootQtySpin.value
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

            // ==================== COLONNE 1 : IDENTITÉ ====================
            ColumnLayout {
                Layout.preferredWidth: 260
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacingM

                Text {
                    text: "Identité"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacingS

                    Text {
                        text: "📝"
                        font.pixelSize: Theme.fontSizeLarge
                        color: Theme.textSecondary
                    }
                    MeowTextField {
                        id: nameInput
                        Layout.fillWidth: true
                        placeholderText: "Nom de l'ennemi..."
                        Keys.onReturnPressed: {
                            focus = false
                            root.focusReleased()
                        }
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Modèle"
                    MeowComboBox {
                        id: modelCombo
                        Layout.fillWidth: true
                        model: AssetManager.availablePlayerModels()
                    }
                }

                Item { Layout.fillHeight: true }
            }

            Rectangle { Layout.fillHeight: true; width: 1; color: Theme.surfaceHover }

            // ==================== COLONNE 2 : COMBAT ====================
            ColumnLayout {
                Layout.preferredWidth: 260
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacingM

                Text {
                    text: "Combat"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Points de vie"
                    MeowSpinBox {
                        id: maxHpSpin
                        Layout.fillWidth: true
                        from: 1; to: 9999; value: 30
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Dégâts"
                    MeowSpinBox {
                        id: damageSpin
                        Layout.fillWidth: true
                        from: 0; to: 999; value: 5
                    }
                }

                // Les portées/vitesse sont saisies en dixièmes de cellule
                // (MeowSpinBox est entier) : 12 → 1.2 cellules.
                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Portée (×0.1)"
                    MeowSpinBox {
                        id: rangeSpin
                        Layout.fillWidth: true
                        from: 1; to: 200; value: 12
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Cooldown (ms)"
                    MeowSpinBox {
                        id: cooldownSpin
                        Layout.fillWidth: true
                        from: 100; to: 10000; stepSize: 100; value: 1000
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Aggro (×0.1)"
                    MeowSpinBox {
                        id: aggroSpin
                        Layout.fillWidth: true
                        from: 0; to: 500; value: 40
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Vitesse (×0.1)"
                    MeowSpinBox {
                        id: speedSpin
                        Layout.fillWidth: true
                        from: 0; to: 200; value: 20
                    }
                }

                Item { Layout.fillHeight: true }
            }

            Rectangle { Layout.fillHeight: true; width: 1; color: Theme.surfaceHover }

            // ==================== COLONNE 3 : LOOT ====================
            ColumnLayout {
                Layout.preferredWidth: 220
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacingM

                Text {
                    text: "Loot"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                // labelWidth resserré : labels courts + spinbox Monnaie large
                // (99 999) — la colonne fait 220px, le labelWidth par défaut
                // (120) ferait déborder la ligne sur la colonne Action.
                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Monnaie"
                    labelWidth: Theme.px(64)
                    MeowSpinBox {
                        id: lootCurrencySpin
                        Layout.fillWidth: true
                        from: 0; to: 99999; stepSize: 5; value: 0
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Objet"
                    labelWidth: Theme.px(64)
                    MeowTextField {
                        id: lootItemField
                        Layout.fillWidth: true
                        placeholderText: "Vide = aucun..."
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Quantité"
                    labelWidth: Theme.px(64)
                    visible: lootItemField.text !== ""
                    MeowSpinBox {
                        id: lootQtySpin
                        Layout.fillWidth: true
                        from: 1; to: 99; value: 1
                    }
                }

                MeowInfoBox {
                    Layout.fillWidth: true
                    text: "Crédité au tueur à la mort de l'ennemi " +
                          "(modules monnaie/inventaire)."
                }

                Item { Layout.fillHeight: true }
            }

            Rectangle { Layout.fillHeight: true; width: 1; color: Theme.surfaceHover }

            // ==================== COLONNE 3 : ACTION ====================
            ColumnLayout {
                Layout.preferredWidth: 160
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
                    iconText: root.isPoseArmed ? "❌" : "👹"
                    text: root.isPoseArmed ? "Annuler" : "Poser un ennemi"
                    variant: root.isPoseArmed ? "danger" : "primary"
                    fontSize: Theme.fontSizeMedium
                    hoverZoom: false
                    onClicked: {
                        if (root.isPoseArmed) {
                            logic.clearAssetSelection()
                        } else {
                            logic.armEnemyPose(root._currentPoseConfig())
                        }
                    }
                }

                MeowInfoBox {
                    Layout.fillWidth: true
                    visible: root.isPoseArmed
                    text: "Cliquez sur la grille pour poser l'ennemi.\nClic droit pour annuler."
                }

                MeowInfoBox {
                    Layout.fillWidth: true
                    text: "En jeu : l'ennemi poursuit le joueur dans son rayon d'aggro " +
                          "et attaque à portée. Attaquez avec Espace."
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
