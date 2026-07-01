import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import editorBottomPanel
import AssetManager
import NPCParameter
import theme
import ui_item

/**
 * Panneau du module "PNJ" : configuration de l'identité (nom + visuel) et du
 * mode de déclenchement, puis armement de la pose. La pose passe par le chemin
 * UI standard (EM_POSE → TileLogic.placeSelectedAsset, branche npcPoseArmed)
 * pour rester compatible collab/undo.
 *
 * L'édition du PNJ déjà posé (lignes de dialogue, zone de trigger) se fait
 * dans le module "config" (NPCConfigurationPanelSection / sections NCP_*).
 */
EBP_Content {
    id: root

    required property var logic

    readonly property bool isPoseArmed: logic && logic.npcPoseArmed

    signal focusReleased()

    sidePanelRatio: 0

    Rectangle {
        anchors.fill: parent
        color: Theme.background
    }

    // Construit la config de pose depuis l'état courant du formulaire.
    function _currentPoseConfig() {
        return {
            npcName: nameInput.text,
            visualKind: visualKindCombo.currentIndex,   // 0 = Model3D, 1 = Sprite2D
            modelName: visualKindCombo.currentIndex === NPCParameter.Model3D
                       ? modelCombo.currentText : "",
            triggerMode: triggerCombo.currentIndex,
            // Sprite : capture le triplet de l'asset armé dans le module Déco.
            spriteCategory: logic ? logic.currentSelectedAssetCategory : "",
            spriteType: logic ? logic.currentSelectedAssetType : "",
            spriteId: logic ? logic.currentSelectedAssetId : ""
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
                        placeholderText: "Nom du PNJ..."
                        Keys.onReturnPressed: {
                            focus = false
                            root.focusReleased()
                        }
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Visuel"
                    MeowComboBox {
                        id: visualKindCombo
                        Layout.fillWidth: true
                        model: ["Modèle 3D", "Sprite 2D"]
                    }
                }

                MeowPropertyRow {
                    Layout.fillWidth: true
                    label: "Modèle"
                    visible: visualKindCombo.currentIndex === NPCParameter.Model3D
                    MeowComboBox {
                        id: modelCombo
                        Layout.fillWidth: true
                        model: AssetManager.availablePlayerModels()
                    }
                }

                MeowInfoBox {
                    Layout.fillWidth: true
                    visible: visualKindCombo.currentIndex === NPCParameter.Sprite2D
                    text: (logic && logic.isAssetSelected)
                          ? "Sprite : " + logic.currentSelectedAssetId
                          : "Sélectionnez d'abord un asset dans le module Déco,\npuis armez la pose du PNJ."
                }

                Item { Layout.fillHeight: true }
            }

            Rectangle { Layout.fillHeight: true; width: 1; color: Theme.surfaceHover }

            // ==================== COLONNE 2 : DÉCLENCHEMENT ====================
            ColumnLayout {
                Layout.preferredWidth: 220
                Layout.alignment: Qt.AlignTop
                spacing: Theme.spacingM

                Text {
                    text: "Déclenchement"
                    font.pixelSize: Theme.fontSizeBody
                    font.bold: true
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignHCenter
                }

                MeowComboBox {
                    id: triggerCombo
                    Layout.fillWidth: true
                    model: ["Proximité", "Clic", "Toujours visible"]
                }

                MeowInfoBox {
                    Layout.fillWidth: true
                    text: {
                        switch (triggerCombo.currentIndex) {
                        case NPCParameter.Proximity:
                            return "Le dialogue s'ouvre quand le joueur entre dans la zone " +
                                   "de proximité liée (à créer dans le module Config après la pose)."
                        case NPCParameter.Click:
                            return "Le dialogue s'ouvre au clic sur la bulle 💬 du PNJ."
                        default:
                            return "La première ligne est affichée en permanence (pancarte)."
                        }
                    }
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
                    iconText: root.isPoseArmed ? "❌" : "🎭"
                    text: root.isPoseArmed ? "Annuler" : "Poser un PNJ"
                    variant: root.isPoseArmed ? "danger" : "primary"
                    fontSize: Theme.fontSizeMedium
                    hoverZoom: false
                    onClicked: {
                        if (root.isPoseArmed) {
                            logic.clearAssetSelection()
                        } else {
                            logic.armNpcPose(root._currentPoseConfig())
                        }
                    }
                }

                MeowInfoBox {
                    Layout.fillWidth: true
                    visible: root.isPoseArmed
                    text: "Cliquez sur la grille pour poser le PNJ.\nClic droit pour annuler."
                }

                Item { Layout.fillHeight: true }
            }
        }
    }
}
