import QtQuick 2.15
import QtQuick.Controls
import QtQuick.Layouts
import Case
import CaseRestArea
import MeowStyle
import Player
import "panel"

Rectangle {
    id: root

    // Propriétés
    property var targetSnapableCase: null
    property var targetCase: null
    property var targetPlayer: null
    property bool isVisible: false
    property bool isPlayerConfiguration: false // Indique si on configure un joueur ou une case

    // Propriétés internes pour éviter les binding loops
    property bool updatingValues: false

    // Signaux
    signal configurationClosed()
    signal configurationApplied(var caseData)
    signal playerConfigurationApplied(var playerData)
    signal requestChangeType(var newType)

    visible: isVisible
    color: "#f8f9fa"
    border.color: "#dee2e6"
    border.width: 2
    radius: 8

    width: 600
    height: 700

    z: 1000  // Au-dessus de tout

    ScrollView {
        anchors.fill: parent
        anchors.margins: 15
        contentWidth: availableWidth
        clip: true

        ColumnLayout {
            width: parent.width
            spacing: 15

            // En-tête
            CaseConfigurationHeader {
                Layout.fillWidth: true
                onCloseClicked: {
                    root.isVisible = false
                    configurationClosed()
                }
            }

            // // Sélection du type de configuration
            // GroupBox {
            //     title: "Type d'élément"
            //     Layout.fillWidth: true

            //     ColumnLayout {
            //         anchors.fill: parent
            //         spacing: 10

            //         // Switch pour choisir entre joueur et case
            //         RowLayout {
            //             Layout.fillWidth: true
            //             spacing: 20

            //             RadioButton {
            //                 id: caseRadio
            //                 text: "Case"
            //                 checked: !isPlayerConfiguration
            //                 onCheckedChanged: {
            //                     if (checked) {
            //                         root.isPlayerConfiguration = false
            //                         updateControls()
            //                     }
            //                 }
            //             }

            //             RadioButton {
            //                 id: playerRadio
            //                 text: "Joueur"
            //                 checked: isPlayerConfiguration
            //                 onCheckedChanged: {
            //                     if (checked) {
            //                         root.isPlayerConfiguration = true
            //                         updateControls()
            //                     }
            //                 }
            //             }
            //         }
            //     }
            // }

            // Sélecteur de type de case (visible uniquement si c'est une case)
            GroupBox {
                title: "Type de Case"
                Layout.fillWidth: true
                visible: !isPlayerConfiguration

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Text {
                        text: "Sélectionnez le type de case :"
                        font.pixelSize: 12
                        color: "#6c757d"
                        font.italic: true
                    }

                    CaseTypeSelector {
                        id: caseTypeSelector
                        Layout.fillWidth: true
                        currentType: targetCase ? targetCase.type : Case.CS_Unknow
                        updatingValues: root.updatingValues

                        onTypeChanged: function(newType) {
                            if (!root.updatingValues && targetCase) {
                                requestChangeType(newType);
                            }
                        }
                    }
                }
            }

            // Sélecteur de joueur (visible uniquement si c'est un joueur)
            GroupBox {
                title: "Configuration Joueur"
                Layout.fillWidth: true
                visible: isPlayerConfiguration

                PlayerSelector {
                    id: playerSelector
                    Layout.fillWidth: true
                    currentPlayer: targetPlayer
                    updatingValues: root.updatingValues

                    onPlayerPropertyChanged: function(property, newValue) {
                        if (!root.updatingValues && targetPlayer) {
                            if (property === "name") {
                                targetPlayer.name = newValue;
                            } else if (property === "color") {
                                targetPlayer.color = newValue;
                            } else if (property === "indexLogo") {
                                targetPlayer.indexLogo = newValue;
                            }
                        }
                    }
                }
            }

            // Configuration générale pour les cases
            CaseGeneralConfig {
                id: caseGeneralConfig
                targetCase: root.targetCase
                Layout.fillWidth: true
                visible: !isPlayerConfiguration
            }

            // Configuration spécifique RestArea
            CaseRestAreaSpecificConfig {
                id: caseRestAreaSpecificConfig
                targetCase: root.targetCase
                Layout.fillWidth: true
                visible: !isPlayerConfiguration && targetCase && targetCase.type === Case.CS_RestArea
            }

            // Configuration spécifique KibbleDispenser
            CaseKibbleDispenserSpecificConfig {
                id: caseKibbleDispenserSpecificConfig
                targetCase: root.targetCase
                Layout.fillWidth: true
                visible: !isPlayerConfiguration && targetCase && targetCase.type === Case.CS_KibbleDispenser
            }

            // Configuration spécifique CardBoardBox
            CaseCardBoardBoxSpecificConfig {
                id: caseCardBoardBoxSpecificConfig
                targetCase: root.targetCase
                Layout.fillWidth: true
                visible: !isPlayerConfiguration && targetCase && targetCase.type === Case.CS_CardBoardBox
            }

            // Configuration spécifique CatDevice
            CaseCatDeviceSpecificConfig {
                id: caseCatDeviceSpecificConfig
                targetCase: root.targetCase
                Layout.fillWidth: true
                visible: !isPlayerConfiguration && targetCase && targetCase.type === Case.CS_Device
            }

            // Boutons d'action
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10

                Item { Layout.fillWidth: true } // Spacer

                Button {
                    text: "Annuler"
                    background: Rectangle {
                        color: "#6c757d"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        root.isVisible = false
                        configurationClosed()
                    }
                }

                Button {
                    text: "Appliquer"
                    background: Rectangle {
                        color: "#28a745"
                        radius: 4
                    }
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    onClicked: {
                        if (isPlayerConfiguration) {
                            playerConfigurationApplied(targetPlayer)
                        } else {
                            configurationApplied(targetCase)
                        }
                        root.isVisible = false
                        configurationClosed()
                    }
                }
            }
        }
    }

    // Fonctions utilitaires
    function getCaseTypeName(type) {
        // Utilise la méthode helper du singleton MeowStyle
        return MeowStyle.getCaseTypeName(type)
    }

    function findFamilyIndex(familyValue) {
        const families = [
            CaseRestArea.FT_NONE, CaseRestArea.FT_BROWN, CaseRestArea.FT_LIGHTBLUE,
            CaseRestArea.FT_PINK, CaseRestArea.FT_ORANGE, CaseRestArea.FT_RED,
            CaseRestArea.FT_YELLOW, CaseRestArea.FT_GREEN, CaseRestArea.FT_DARKBLUE
        ]
        return families.indexOf(familyValue)
    }

    // Fonction pour ouvrir le panneau avec un élément (case ou joueur)
    function openConfiguration(snapableElement) {
        // Déterminer le type de l'élément
        if (snapableElement.playerData !== undefined) {
            // C'est un joueur
            targetPlayer = snapableElement.playerData
            targetCase = null
            targetSnapableCase = snapableElement
            isPlayerConfiguration = true
        } else if (snapableElement.caseData !== undefined) {
            // C'est une case
            targetCase = snapableElement.caseData
            targetPlayer = null
            targetSnapableCase = snapableElement
            isPlayerConfiguration = false
        }

        isVisible = true
        updateControls()
    }

    // Fonction pour mettre à jour tous les contrôles
    function updateControls() {
        updatingValues = true

        if (isPlayerConfiguration) {
            // Mise à jour des contrôles joueur
            if (targetPlayer) {
                playerSelector.updateControls()
            }
        } else {
            // Mise à jour des contrôles case
            if (targetCase) {
                // Mise à jour du sélecteur de type
                caseTypeSelector.setCurrentType(targetCase.type)

                // Mise à jour des contrôles généraux
                caseGeneralConfig.updateControls()

                // Mise à jour des contrôles spécifiques
                updateSpecificPanels()
            }
        }

        updatingValues = false
    }

    // Fonction pour mettre à jour les panneaux spécifiques selon le type
    function updateSpecificPanels() {
        if (!targetCase) return

        // Mise à jour des contrôles RestArea
        if (targetCase.type === Case.CS_RestArea) {
            caseRestAreaSpecificConfig.updateControls()
        }

        // Mise à jour des contrôles KibbleDispenser
        if (targetCase.type === Case.CS_KibbleDispenser) {
            caseKibbleDispenserSpecificConfig.updateControls()
        }

        // Mise à jour des contrôles CardBoardBox
        if (targetCase.type === Case.CS_CardBoardBox) {
            caseCardBoardBoxSpecificConfig.updateControls()
        }

        // Mise à jour des contrôles CatDevice
        if (targetCase.type === Case.CS_Device) {
            caseCatDeviceSpecificConfig.updateControls()
        }
    }
}
