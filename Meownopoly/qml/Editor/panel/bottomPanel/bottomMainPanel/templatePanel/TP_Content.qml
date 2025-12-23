import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import EditorEnum

import "../"
import editorBottomPanel

/**
 * Panneau pour gérer les templates (groupes d'éléments réutilisables)
 */
EBP_Content {
    id: root

    required property var logic

    // Propriétés internes pour gérer l'état de l'interface
    property string templateName: ""
    
    // Propriété pour suivre le nombre d'éléments sélectionnés
    property int selectedElementsCount: 0

    // Signaux
    signal templateCreated(string name, var elements)
    signal templateCancelled()

    sidePanelRatio: 0

    // Activer automatiquement le mode template quand le panneau devient visible
    onVisibleChanged: {
        if (visible) {
            activateTemplateMode()
        } else {
            deactivateTemplateMode()
        }
    }

    Component.onCompleted: {
        if (visible) {
            activateTemplateMode()
        }
    }

    function activateTemplateMode() {
        if (logic && logic.editorMouseMode !== EditorEnum.EM_TEMPLATE) {
            logic.editorMouseMode = EditorEnum.EM_TEMPLATE
            console.log("Template mode activated")
        }
    }

    function deactivateTemplateMode() {
        if (logic && logic.editorMouseMode === EditorEnum.EM_TEMPLATE) {
            logic.editorMouseMode = EditorEnum.EM_NORMAL
            console.log("Template mode deactivated")
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        // --- En-tête ---
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                text: "Création de Template"
                font.pointSize: 13
                font.bold: true
                color: "white"
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "Cliquez sur les éléments pour les sélectionner/désélectionner."
                font.pointSize: 8
                color: "#aaaaaa"
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }

        // Séparateur
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: "#444444"
        }

        // Layout horizontal principal
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 15

            // ==================== COLONNE GAUCHE ====================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / 2
                Layout.alignment: Qt.AlignTop
                spacing: 8

                // --- Nom du template ---
                Text {
                    text: "Nom du template"
                    color: "white"
                    font.pointSize: 10
                    font.bold: true
                }

                TextField {
                    id: templateNameField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 36
                    placeholderText: "Entrez le nom du template..."
                    placeholderTextColor: "#888888"
                    color: "white"
                    font.pointSize: 10

                    background: Rectangle {
                        color: "#333333"
                        radius: 6
                        border.color: templateNameField.activeFocus ? "#4A90E2" : "#555555"
                        border.width: templateNameField.activeFocus ? 2 : 1
                    }

                    onTextChanged: {
                        root.templateName = text
                    }
                }

                // --- Indicateur de sélection compact ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    color: "#2c3e50"
                    radius: 6
                    border.color: root.selectedElementsCount > 0 ? "#4CAF50" : "#555555"
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 8
                        spacing: 8

                        Text {
                            text: "Éléments sélectionnés :"
                            font.pointSize: 9
                            color: "#aaaaaa"
                        }

                        Text {
                            text: root.selectedElementsCount.toString()
                            font.pointSize: 12
                            font.bold: true
                            color: root.selectedElementsCount > 0 ? "#4CAF50" : "#888888"
                        }

                        Item { Layout.fillWidth: true }
                    }
                }

                // Spacer
                Item {
                    Layout.fillHeight: true
                }
            }

            // ==================== COLONNE DROITE ====================
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: parent.width / 2
                Layout.alignment: Qt.AlignTop
                spacing: 8

                // --- Instructions ---
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: instructionsText.height + 12
                    color: "#2c3e50"
                    radius: 6
                    border.color: "#4A90E2"
                    border.width: 1

                    Text {
                        id: instructionsText
                        anchors.centerIn: parent
                        width: parent.width - 12
                        text: "• Clic : sélectionner/désélectionner\n• Le rectangle s'adapte automatiquement"
                        font.pointSize: 8
                        color: "#4A90E2"
                        wrapMode: Text.WordWrap
                        horizontalAlignment: Text.AlignLeft
                        lineHeight: 1.2
                    }
                }

                // --- Boutons d'action ---
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    // Bouton Créer Template
                    Button {
                        id: createTemplateButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        enabled: root.selectedElementsCount > 0 && root.templateName.length > 0

                        text: "✅ Créer"

                        background: Rectangle {
                            radius: 6
                            color: createTemplateButton.enabled ? "#4CAF50" : "#555555"
                            border.color: Qt.lighter(color, 1.2)
                            border.width: 1
                            opacity: createTemplateButton.hovered && createTemplateButton.enabled ? 0.9 : 1.0
                        }

                        contentItem: Text {
                            text: createTemplateButton.text
                            font.pointSize: 10
                            font.bold: true
                            color: createTemplateButton.enabled ? "white" : "#888888"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            createTemplate()
                        }
                    }

                    // Bouton Annuler
                    Button {
                        id: cancelButton
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        text: "🗑️ Annuler"

                        background: Rectangle {
                            radius: 6
                            color: "#c0392b"
                            border.color: Qt.lighter(color, 1.2)
                            border.width: 1
                            opacity: cancelButton.hovered ? 0.9 : 1.0
                        }

                        contentItem: Text {
                            text: cancelButton.text
                            font.pointSize: 10
                            color: "white"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            cancelTemplateCreation()
                        }
                    }
                }

                // Spacer
                Item {
                    Layout.fillHeight: true
                }
            }
        }
    }

    // --- Fonctions utilitaires ---

    function createTemplate() {
        if (logic && logic.mouseLogic) {
            var selectedElements = logic.mouseLogic.selectedElements
            if (selectedElements.length > 0) {
                // Générer le rectangle englobant
                var boundingRect = logic.mouseLogic.calculateBoundingRectangle()
                
                // Émettre le signal avec les informations du template
                root.templateCreated(root.templateName, {
                    name: root.templateName,
                    elements: selectedElements,
                    boundingRect: boundingRect
                })
                
                console.log("Template créé:", root.templateName, "avec", selectedElements.length, "éléments")
                
                // Réinitialiser l'interface
                resetInterface()
            }
        }
    }

    function cancelTemplateCreation() {
        if (logic && logic.mouseLogic) {
            logic.mouseLogic.unselectSelectedElements()
        }
        root.templateCancelled()
    }

    function resetInterface() {
        templateNameField.text = ""
        root.templateName = ""
        
        if (logic && logic.mouseLogic) {
            logic.mouseLogic.unselectSelectedElements()
        }
    }

    // Mise à jour automatique du compteur d'éléments sélectionnés
    Binding {
        target: root
        property: "selectedElementsCount"
        value: (logic && logic.mouseLogic && logic.mouseLogic.selectedElements) 
               ? logic.mouseLogic.selectedElements.length 
               : 0
        when: logic && logic.mouseLogic
    }
    
    // Connexion au signal templateSelectionChanged (seulement quand mouseLogic est disponible)
    Connections {
        id: templateConnections
        enabled: logic && logic.mouseLogic
        target: enabled ? logic.mouseLogic : null
        function onTemplateSelectionChanged() {
            if (logic && logic.mouseLogic && logic.mouseLogic.selectedElements) {
                root.selectedElementsCount = logic.mouseLogic.selectedElements.length
            }
        }
    }
}











